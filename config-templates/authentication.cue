import (
	"vela/config"
    "encoding/base64"
)

metadata: {
	name:        "authentication"
	alias:       "Basic Authentication"
	description: "Config information to store Basic Authentication: Username - Password(Token)"
	sensitive:   true
	scope:       "project"
}

template: {
	output: {
		apiVersion: "v1"
        kind:       "Secret"
        metadata: {
            name:      context.name
            namespace: context.namespace
            labels: {
				"config.oam.dev/catalog":       "velacore-config"
				"config.oam.dev/type":          "git-token"
				"config.oam.dev/multi-cluster": "true"
			}
		}
		type: "Opaque"
        stringData: {
            if parameter.username != _|_ {
				username: parameter.username
			}
			if parameter.password != _|_ {
				password: parameter.password
			}
        }
	}

	parameter: {
		username?: string
		password?: string
	}	
}
