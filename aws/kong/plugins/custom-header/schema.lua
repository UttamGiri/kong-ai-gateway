local typedefs = require "kong.db.schema.typedefs"

return {
  name = "custom-header",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { header_name = { type = "string", default = "X-Kong-AI-Gateway" } },
          { header_value = { type = "string", default = "oss" } },
        },
      },
    },
  },
}
