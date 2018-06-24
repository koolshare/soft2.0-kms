local nixio = require "nixio"
local ksutil = require "luci.ksutil"

module("luci.controller.apps.kms.index", package.seeall)

function index()
	entry({"apps", "kms"}, call("action_index"))
end

function action_index()
    ksutil.shell_action("kms")
end
