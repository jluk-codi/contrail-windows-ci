def call(Map params) {
  def prepareHardwareConfig = params.config
  def playbook = params.playbook
  def vm_role = params.vm_role
  def vmware_folder = params.vmware_folder
  def vmWareConfig
  pipeline {
    agent none

    environment {
      // `VC` has to be defined in outer scope to properly
      // strip credentials from logs in all child scopes (all stages).
      // Please do not move to `Prepare environment` stage.
      VC = credentials('vcenter')
      VC_FOLDER = vmware_folder.toString()
    }

    stages {
      stage('Prepare environment') {
        agent { label 'ansible' }
        steps {
          dir('ansible') {
            sh 'cp inventory.sample inventory'
            script {
              vmWareConfig = getVMwareConfig(vm_role)
              if (params.vc_datastore_name) {
                vmWareConfig.vcenter_datastore_name = params.vc_datastore_name
              }

              prepareHardwareConfig(params)
            }
          }
        }
      }
      stage('Run ansible') {
        agent { label 'ansible' }
        steps {
          dir('ansible') {
            ansiblePlaybook extras: '-e @vm.vars', \
                            inventory: 'inventory', \
                            playbook: playbook, \
                            sudoUser: 'ubuntu', \
                            extraVars: vmWareConfig
          }
        }
      }
    }
  }
}
