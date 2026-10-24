local CustomHeader = {
  PRIORITY = 1000,
  VERSION = "0.1.0",
}

function CustomHeader:header_filter(conf)
  kong.response.set_header(conf.header_name, conf.header_value)
end

return CustomHeader
