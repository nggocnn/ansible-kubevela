metadata: {
	name:        "ssh-privatekey"
	alias:       "SSH Private Key"
	description: "Config information to store SSH Private Key"
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
				"config.oam.dev/type":          "ssh-privatekey"
				"config.oam.dev/multi-cluster": "true"
			}
		}
		type: "Opaque"
		stringData: {
			"ssh-privatekey-base64": parameter.sshPrivateKey
		}
	}

	parameter: {
		// +usage=The SSH Private Key.
		sshPrivateKey: string
	}
}
