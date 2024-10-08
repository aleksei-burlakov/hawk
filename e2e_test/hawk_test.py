#!/usr/bin/python3
# Copyright (C) 2019 SUSE LLC
"""HAWK GUI interface Selenium test: tests hawk GUI with Selenium using firefox or chrome"""

import argparse
import ipaddress
import socket
import sys


from pyvirtualdisplay import Display

from hawk_test_driver import HawkTestDriver
from hawk_test_results import ResultSet
from hawk_test_ssh import HawkTestSSH


def hostname(string):
    '''
    Check if the input string as hostname is reachable
    Args:
        string (str): input destination
    Return:
        string (str) or None
    Raises:
        ArgumentTypeError: via socket.gaierror: [Errno -2] Name or service not known
    '''
    try:
        socket.getaddrinfo(string, 1)
        return string
    except socket.gaierror:
        raise argparse.ArgumentTypeError(f"Unknown host: {string}")  # pylint: disable=raise-missing-from


def cidr_address(string):
    '''
    Check if the input string is IP address format
    Args:
       string (str): input destination
    Return:
       string (str) or None
    Raises:
       ArgumentTypeError: via ValueError if address does not represent a valid IPv4 or IPv6 address
    '''
    try:
        ipaddress.ip_network(string, False)
        return string
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"Invalid CIDR address: {string}") from exc


def port(string):
    '''
    Check if the input string is digit and valid port number
    Args:
        string (str): input port number
    Return:
        string (str)
    Raises:
        ArgumentTypeError: via ValueError
    '''
    if string.isdigit() and 1 <= int(string) <= 65535:
        return string
    raise argparse.ArgumentTypeError(f"Invalid port number: {string}") from ValueError


def parse_args():
    '''
    Set arguments for ArgumentParser
    Return:
         argparse.Namespace object
    '''
    parser = argparse.ArgumentParser(description='HAWK GUI interface Selenium test')
    parser.add_argument('-b', '--browser', default='firefox', choices=['firefox', 'chrome', 'chromium'],
                        help='Browser to use in the test')
    parser.add_argument('-H', '--host', default='localhost', type=hostname,
                        help='Host or IP address where HAWK is running')
    parser.add_argument('-S', '--slave', type=hostname,
                        help='Host or IP address of the slave')
    parser.add_argument('-I', '--virtual-ip', type=cidr_address,
                        help='Virtual IP address in CIDR notation')
    parser.add_argument('-P', '--port', default='7630', type=port,
                        help='TCP port where HAWK is running')
    parser.add_argument('-s', '--secret',
                        help='root SSH Password of the HAWK node')
    parser.add_argument('-r', '--results',
                        help='Generate hawk_test.results file')
    parser.add_argument('--xvfb', action='store_true',
                        help='Use Xvfb. Headless mode')
    args = parser.parse_args()
    return args


def main():
    '''
    Main test functions
    '''
    args = parse_args()

    if args.xvfb:
        global DISPLAY  # pylint: disable=global-statement
        DISPLAY = Display()
        DISPLAY.start()

    # Initialize results set
    results = ResultSet()
    results.add_ssh_tests()

    # Establish SSH connection to verify status
    ssh = HawkTestSSH(args.host, args.secret)

    # Get version from /etc/os-release
    test_version = ssh.ssh.exec_command("grep VERSION= /etc/os-release")[1].read().decode().strip().split("=")[1].strip('"')

    # Create driver instance
    browser = HawkTestDriver(addr=args.host, port=args.port,
                             browser=args.browser, headless=args.xvfb,
                             version=test_version)

    # Resources to create
    cluster = 'Anderes'
    primitive = 'cool_primitive'
    clone = 'cool_clone'
    group = 'cool_group'

    # Tests to perform
    if args.virtual_ip:
        browser.test('test_add_virtual_ip', results, args.virtual_ip)
        browser.test('test_remove_virtual_ip', results)
    else:
        results.set_test_status('test_add_virtual_ip', 'skipped')
        results.set_test_status('test_remove_virtual_ip', 'skipped')
    browser.test('test_set_stonith_maintenance', results)
    ssh.verify_stonith_in_maintenance(results)
    browser.test('test_disable_stonith_maintenance', results)
    browser.test('test_view_details_first_node', results)
    browser.test('test_clear_state_first_node', results)
    browser.test('test_set_first_node_maintenance', results)
    ssh.verify_node_maintenance(results)
    browser.test('test_disable_maintenance_first_node', results)
    browser.test('test_add_new_cluster', results, cluster)
    browser.test('test_remove_cluster', results, cluster)
    browser.test('test_click_on_history', results)
    browser.test('test_generate_report', results)
    browser.test('test_click_on_command_log', results)
    browser.test('test_click_on_status', results)
    browser.test('test_add_primitive', results, primitive)
    ssh.verify_primitive(primitive, test_version, results)
    browser.test('test_remove_primitive', results, primitive)
    ssh.verify_primitive_removed(primitive, results)
    browser.test('test_add_clone', results, clone)
    browser.test('test_remove_clone', results, clone)
    browser.test('test_add_group', results, group)
    browser.test('test_remove_group', results, group)
    browser.test('test_check_cluster_configuration', results, ssh)
    browser.test('test_click_around_edit_conf', results)
    if args.slave:
        browser.addr = args.slave
        browser.test('test_fencing', results)
    else:
        results.set_test_status('test_fencing', 'skipped')

    # Save results if run with -r or --results
    if args.results:
        results.logresults(args.results)

    return results.get_failed_tests_total()


if __name__ == "__main__":
    import warnings
    warnings.filterwarnings(action='ignore', module='.*paramiko.*')

    DISPLAY = None
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        if DISPLAY is not None:
            DISPLAY.stop()
        sys.exit(1)
    finally:
        if DISPLAY is not None:
            DISPLAY.stop()
