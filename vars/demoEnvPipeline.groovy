def call(playbookToRun) {
    def testenvConfig

    pipeline {
        agent { label "ansible" }

        environment {
            DEMOENV_FOLDER = "WINCI"
            DEMOENV_MGMT_NETWORK = "VM-Network"
            VCENTER_DATASTORE_CLUSTER = "WinCI-Datastores-SATA"
        }

        stages {
            stage("Run Ansible playbook") {
                steps {
                    script {
                        testenvConfig = [
                            testenv_name: env.DEMOENV_NAME,
                            testenv_folder: env.DEMOENV_FOLDER,
                            testenv_mgmt_network: env.DEMOENV_MGMT_NETWORK,
                            testenv_data_network: env.DEMOENV_DATA_NETWORK,
                            testenv_testbed_template: env.TESTBED_TEMPLATE,
                            testenv_controller_template: env.CONTROLLER_TEMPLATE,
                            vcenter_datastore_cluster: env.VCENTER_DATASTORE_CLUSTER
                        ]
                    }

                    dir('ansible') {
                        ansiblePlaybook inventory: 'inventory.testenv',
                                        extraVars: testenvConfig,
                                        playbook: playbookToRun
                    }
                }
            }
        }
    }
}
