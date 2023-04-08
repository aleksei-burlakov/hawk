# Copyright (c) 2009-2015 Tim Serong <tserong@suse.com>
# See COPYING for license.

module TicketHelper
  def ticket_losspolicy_options(selected)
    options_for_select(
      [
        [_("Stop"), "stop"],
        [_("Demote"), "demote"],
        [_("Fence"), "fence"],
        [_("Freeze"), "freeze"]
      ],
      selected
    )
  end

  def available_ticket_roles
    {
      "Started" => _("Started"),
      "Master" => _("Promoted"),
      "Slave" => _("Promotable"),
      "Stopped" => _("Stopped")
    }
  end

  def available_ticket_resources
    [
      @cib.resources.map{|x| x[:id]},
      @cib.templates.map{|x| x[:id]}
    ].flatten.sort do |a, b|
      a.natcmp(b, true)
    end
  end
end
