local typedefs = require "kong.db.schema.typedefs"

return {
  name = "custom-request-id",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { header_name = { type = "string", default = "X-Request-Id" } },
        },
      },
    },
  },
}
