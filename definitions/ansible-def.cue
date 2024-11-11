import "strings"

ansible: {
	type: "component"
	annotations: {}
	labels: {}
	description: "Ansible Component create K8s Job to run Ansible playbook from Git Repository"
	attributes: {
		workload: {
			definition: {
				apiVersion: "batch/v1"
				kind:       "Job"
			}
			type: "jobs.batch"
		}
		status: {
			customStatus: #"""
				status: {
					active:    *0 | int
					failed:    *0 | int
					succeeded: *0 | int
				} & {
					if context.output.status.active != _|_ {
						active: context.output.status.active
					}
					if context.output.status.failed != _|_ {
						failed: context.output.status.failed
					}
					if context.output.status.succeeded != _|_ {
						succeeded: context.output.status.succeeded
					}
				}
				message: "Active/Failed/Succeeded:\(status.active)/\(status.failed)/\(status.succeeded)"
				"""#
			healthPolicy: #"""
				succeeded: *0 | int
				if context.output.status.succeeded != _|_ {
					succeeded: context.output.status.succeeded
				}
				isHealth: succeeded == context.output.spec.parallelism
				"""#
		}
	}
}

template: {
	output: {
		apiVersion: "batch/v1"
		kind:       "Job"
		spec: {
			backoffLimit: 0
			template: {
				metadata: {
					labels: {
						if parameter.labels != _|_ {
							parameter.labels
						}
						"app.oam.dev/name":      context.appName
						"app.oam.dev/component": context.name
					}
					if parameter.annotations != _|_ {
						annotations: parameter.annotations
					}
				}
				spec: {
					restartPolicy: *parameter.restartPolicy | "Never"
					containers: [{
						name:  context.name
						image: "nggocnn/ansible-playbook:v0.2"

						if parameter.imagePullPolicy != _|_ {
							imagePullPolicy: parameter.imagePullPolicy
						}

						if parameter.imagePullSecrets != _|_ {
							imagePullSecrets: [
								for secret in parameter.imagePullSecrets {
									name: secret
								},
							]
						}

						command: ["/bin/sh", "-c"]

						args: _setupCommands

						env: _ansibleContainerEnv

						resources: {
							limits: {
								if parameter.cpu != _|_ {
									cpu: parameter.cpu
								}
								if parameter.memory != _|_ {
									memory: parameter.memory
								}
							}
							requests: {
								if parameter.cpu != _|_ {
									cpu: parameter.cpu
								}
								if parameter.memory != _|_ {
									memory: parameter.memory
								}
							}
						}

						volumeMounts: [
							{
								name:      "ansible-source"
								mountPath: "/workspace/ansible"
							},
							if parameter.authConfig.sshKeyRef != _|_ {
								if parameter.authConfig.sshKeyRef != "" {
									{
										name:      "sshkey"
										mountPath: "/workspace/sshkey"
									}
								}
							},
						]
					}]
					initContainers: [{
						name:  "git-clone"
						image: "alpine/git:latest"

						if parameter.imagePullPolicy != _|_ {
							imagePullPolicy: parameter.imagePullPolicy
						}

						if parameter.imagePullSecrets != _|_ {
							imagePullSecrets: [
								for secret in parameter.imagePullSecrets {
									name: secret
								},
							]
						}

						command: ["/bin/sh", "-c"]

						args: [
							_gitCloneCommands,
						]

						if parameter.git.secretRef != _|_ {
							env: [
								{
									name: "GIT_ACCESS_TOKEN"
									valueFrom: {
										secretKeyRef: {
											name: parameter.git.secretRef
											key:  "password"
										}
									}
								},
							]
						}

						volumeMounts: [
							{
								name:      "ansible-source"
								mountPath: "/workspace/ansible"
							},
						]
					}]
					volumes: [
						{
							name: "ansible-source"
							emptyDir: {}
						},
						if parameter.authConfig.sshKeyRef != _|_ {
							if parameter.authConfig.sshKeyRef != "" {
								{
									name: "sshkey"
									secret: {
										secretName: parameter.authConfig.sshKeyRef
									}
								}
							}
						},
					]
				}
			}
		}
	}

	_ansiblePlaybookBaseCommand: [
		"ansible-playbook",
		"\(parameter.sourcePlaybook)",
		"-i \(parameter.sourceInventory)",
		if parameter.authConfig.sshKeyRef != _|_ {
			if parameter.authConfig.sshKeyRef  != "" {
				"--private-key /workspace/ansible/ssh-privatekey"
			}
		},
		if parameter.authConfig.sshKeyRef == _|_ && parameter.authConfig.basicAuthRef != _|_ {
			if parameter.authConfig.basicAuthRef != "" {
				"-u $ANSIBLE_USER --extra-vars ansible_password=$ANSIBLE_PASSWORD"
			}
		},
	]

	_ansiblePlaybookCommand: *strings.Join(_ansiblePlaybookBaseCommand, " ") | string
	if parameter.extraArguments != _|_ {
		_ansiblePlaybookCommand: strings.Join(_ansiblePlaybookBaseCommand+parameter.extraArguments, " ")
	}

	_setupCommands: [
		strings.Join([
			if parameter.authConfig.sshKeyRef != _|_ {
				if parameter.authConfig.sshKeyRef != "" {
						"base64 -d /workspace/sshkey/ssh-privatekey-base64 > /workspace/ansible/ssh-privatekey && chmod 0400 /workspace/ansible/ssh-privatekey"
				}
			},
			if parameter.ansibleCollections != _|_ {
				"if [ -f \(parameter.ansibleCollections) ]; then ansible-galaxy collection install -r \(parameter.ansibleCollections); fi"
			},
			_ansiblePlaybookCommand,
		], " && "),
	]

	// Handle Git URL
	_gitUrl: *parameter.git.url | string

	if parameter.git.secretRef != _|_ {
		if parameter.git.secretRef != "" {
			_gitUrl: "https://oauth2:$(echo -n $GIT_ACCESS_TOKEN)@\(strings.TrimPrefix(parameter.git.url, "https://"))"
		}
	}

	// Handle Git clone based on precedence of tag and branch
	_gitCloneCommands: *"git clone \(_gitUrl) /workspace/ansible" | string

	// If tag is provided, clone the specific tag (takes precedence over branch)
	// Tried to simplify this condition expression, but velaux can not render it :'(
	// Sorry, I'm not sure why
	if parameter.git.tag != _|_ {
		if parameter.git.branch != _|_ {
			if parameter.git.branch != "" {
				_gitCloneCommands: *"git clone --branch \(parameter.git.branch) \(_gitUrl) /workspace/ansible" | string
			}
		}
		if parameter.git.tag != "" {
			_gitCloneCommands: "git clone --branch \(parameter.git.tag) \(_gitUrl) /workspace/ansible"
		}
	}

	// If no tag is provided, use the branch (defaults to main)
	if parameter.git.tag == _|_ {
		if parameter.git.branch != _|_ {
			if parameter.git.branch != "" {
				_gitCloneCommands: "git clone --branch \(parameter.git.branch) \(_gitUrl) /workspace/ansible"
			}
		}
	}

	_ansibleContainerEnv: [
		if parameter.authConfig.sshKeyRef == _|_ && parameter.authConfig.basicAuthRef != _|_ {
			if parameter.authConfig.basicAuthRef != "" {
				{
					name: "ANSIBLE_USER"
					valueFrom: {
						secretKeyRef: {
							name: parameter.authConfig.basicAuthRef
							key: "username"
						}
					}
				}
			}
		},
		if parameter.authConfig.sshKeyRef == _|_ && parameter.authConfig.basicAuthRef != _|_ {
			if parameter.authConfig.basicAuthRef != "" {
				{
					name: "ANSIBLE_PASSWORD"
					valueFrom: {
						secretKeyRef: {
							name: parameter.authConfig.basicAuthRef
							key: "password"
						}
					}
				}
			}
		},
		if parameter.env != _|_ for e in parameter.env {
			e
		},
	]

	parameter: {
		// +usage=Specify the labels in the workload
		labels?: [string]: string

		// +usage=Specify the annotations in the workload
		annotations?: [string]: string

		// +usage=Specify image pull policy for your service
		imagePullPolicy?: *"IfNotPresent" | "Always" | "Never"

		// +usage=Specify image pull secrets for your service
		imagePullSecrets?: [...string]

		// +usage=Define the job restart policy, the value can only be Never or OnFailure. By default, it's Never.
		restartPolicy?: *"Never" | "OnFailure"

		git: {
			// +usage=The Git repository URL
			url: string
			// +usage=The Git branch to checkout and monitor for changes, defaults to main branch
			branch?: *"main" | string
			// +usage=The Git tag to checkout and monitor for changes, takes precedence over branch
			tag?: string
			// +usage=The name of the secret containing authentication credentials for Git Repository
			secretRef?: string
		}

		// +usage=Define arguments by using environment variables
		env?: [...{
			// +usage=Environment variable name
			name: string
			// +usage=The value of the environment variable
			value?: string
			// +usage=Specifies a source the value of this var should come from
			valueFrom?: {
				// +usage=Selects a key of a secret in the pod's namespace
				secretKeyRef?: {
					// +usage=The name of the secret in the pod's namespace to select from
					name: string
					// +usage=The key of the secret to select from. Must be a valid secret key
					key: string
				}
				// +usage=Selects a key of a config map in the pod's namespace
				configMapKeyRef?: {
					// +usage=The name of the config map in the pod's namespace to select from
					name: string
					// +usage=The key of the config map to select from. Must be a valid secret key
					key: string
				}
			}
		}]

		// +usage=Number of CPU units for the service, like `0.5` (0.5 CPU core), `1` (1 CPU core)
		cpu?: string

		// +usage=Specifies the attributes of the memory resource required for the container.
		memory?: string

		// +usage=Path of playbook file in source
		sourcePlaybook: *"playbook.yaml" | string

		// +usage=Path of inventory file in source
		sourceInventory: *"inventory" | string

		// +usage=Add extra arguments to ansible-playbook command
		extraArguments?: [...string]

		// +usage=Authentication for Ansible used to connect to remote VMs 
		authConfig: {
			// +usage=Secret contain SSH private key for remote VMs. Private SSH Key will take over Basic (username/password) authentication.
			sshKeyRef?: string

			// +usage=Secret contain username and password for remote VMs
			basicAuthRef?: string
		}

		// +usage=Ansible collection requirements file
		ansibleCollections?: string
	}
}
