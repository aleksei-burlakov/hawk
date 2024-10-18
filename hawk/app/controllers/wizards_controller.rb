# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

class WizardsController < ApplicationController
  before_action :login_required
  before_action :set_title
  before_action :set_cib
  before_action :cib_writable
  before_action :cluster_online

  def index
    # all wizards
    @wizards = Wizard.all

    # byebug # 1. Here we come first (CONFIGURAION->Wizards)
    respond_to do |format|
      format.html
    end
  end

  def show
    # 2. Here we come second
    # (CONFIGURAION->Wizards->Basics->Verify health and configuration)
    # byebug
    session[:hawk_wizard] = params[:id]
    # only one wizard (@name="health", @shortdesc="Verify health and configuration")
    @wizard = Wizard.find params[:id]
    pa = Rails.cache.read("#{session.id}-#{params[:id]}")
    @wizard.update_step_values(@wizard, pa) if pa

    respond_to do |format|
      format.html
    end
  end

  def update
    # 3. Here we come third
    # (CONFIGURAION->Wizards->Basics->Verify health and configuration->Verify)
    # byebug
    @wizard = Wizard.find params[:id]
    pa = build_scriptparams(params.permit!)
    @pa = pa
    Rails.cache.write("#{session.id}-#{params[:id]}", pa, expires_in: 1.hour)
    @wizard.verify(pa)

    respond_to do |format|
      format.html
    end
  end

  def submit
    pa = JSON.parse(params[:pa]) if params[:pa]
    pa = Rails.cache.read("#{session.id}-#{params[:id]}") if pa.nil?

    if pa.nil?
      render json: [_("Session has expired")], status: :unprocessable_entity
    else
      # STOPPED HERE
      # 4. Here we come fourth
      # (CONFIGURAION->Wizards->Basics->Verify health and configuration->Verify->Apply)
      byebug
      @wizard = Wizard.find params[:id] # -> capture3(crm script show health)
      @wizard.verify(pa) # -> capture3(crm script verify health)
      if @wizard.errors.length > 0
        render json: @wizard.errors.to_json, status: :unprocessable_entity
      elsif current_cib.sim?
        render json: [_("Wizard cannot be applied when the simulator is active")], status: :unprocessable_entity
      else
        @wizard.run(pa) # -> capture3(crm script run health)
        byebug
        # The problem description:
        # crm script run health && echo $?  --> 0
        # even if the script has broken
        # (to break add '-D' in "'-Z', 'health-report'"
        # in /usr/share/crmsh/scripts/health/hahealth.py)
        if @wizard.errors.length > 0
          render json: @wizard.errors.to_json, status: :unprocessable_entity
        else
          render json: { actions: @wizard.actions, output: @wizard.output }
        end
      end
    end
  end

  protected

  def build_stepmap(m, container)
    return m if container.nil?
    container.steps.each { |s| m[s.name] = {} unless s.name.empty? || !s.required }
    m
  end

  def build_scriptparams(params)
    sp = build_stepmap({}, @wizard)
    id = @wizard.id
    params.select { |k, _v| k.start_with?("#{id}.") }.each do |k, v|
      next if v.empty?
      path = k.split(".").drop(1)
      if path.length > 1
        basestep_idx = @wizard.steps.find_index { |x| x.name == path[0] }
        next if basestep_idx.nil?

        basestep = @wizard.steps[basestep_idx]
        next unless basestep.required || (params.key?("enable:#{basestep.id}") && params["enable:#{basestep.id}"] != "false")

        name = path.last
        sub = sp
        path.take(path.length - 1).each do |p|
          sub[p] = {} unless sub.key? p
          sub = sub[p]
        end
        sub[name] = v
      else
        sp[path[0]] = v
      end
    end
    # Rails.logger.debug "scriptparams: #{params} -> #{sp}"
    sp
  end

  def default_base_layout
    "withrightbar"
  end

  protected

  def set_title
    @title = _('Use a wizard')
  end

  def set_cib
    @cib = current_cib
  end

  def cib_writable
    begin
      Invoker.instance.cibadmin("--modify", "--allow-create", "--scope",
        "crm_config", "--xml-text", "<cluster_property_set id=\"hawk-rw-test\"/>")

      Invoker.instance.cibadmin("--delete", "--xml-text", "<cluster_property_set id=\"hawk-rw-test\"/>")
    rescue SecurityError
      respond_to do |format|
        format.html do
          redirect_to(
            cib_url(cib_id: @cib.id),
            alert: _("Permission denied - you do not have write access to the CIB.")
          )
        end
        format.json do
          render json: {
            error: _("Permission denied - you do not have write access to the CIB.")
          }, status: :unprocessable_entity
        end
      end
    rescue NotFoundError => e
      Rails.logger.debug "NotFoundError: #{e}"
    rescue RuntimeError => e
      Rails.logger.debug "RuntimeError: #{e}"
    end
  end

  def cluster_online
    Util.safe_x('/usr/sbin/crm_mon', '-s', '>/dev/null', '2>&1')

    if $?.exitstatus == Errno::ENOTCONN::Errno
      respond_to do |format|
        format.html do
          redirect_to(
            cib_url(cib_id: @cib.id),
            alert: _("Cluster seems to be offline")
          )
        end
        format.json do
          render json: {
            error: _("Cluster seems to be offline")
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
