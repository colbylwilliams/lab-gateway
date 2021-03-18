param functionApp string

var githubBranch = 'main'
var githubRepoUrl = 'https://github.com/colbylwilliams/lab-gateway'
var githubRepoPath = 'api'

resource functionAppSourceControl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${functionApp}/web'
  properties: {
    repoUrl: githubRepoUrl
    branch: githubBranch
    isManualIntegration: true
  }
}
