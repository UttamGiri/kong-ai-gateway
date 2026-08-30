local CustomRequestId = {
  PRIORITY = 1001,
  VERSION = "0.1.0",
}

local function new_id()
  return ngx.md5(tostring(ngx.now()) .. tostring(ngx.var.request_id or "") .. tostring(math.random(1, 1e9)))
end

function CustomRequestId:access(conf)
  local id = kong.request.get_header(conf.header_name)
  if not id or id == "" then
    id = new_id()
  end
  kong.ctx.plugin.request_id = id
  kong.service.request.set_header(conf.header_name, id)
end

function CustomRequestId:header_filter(conf)
  kong.response.set_header(conf.header_name, kong.ctx.plugin.request_id)
end

return CustomRequestId
