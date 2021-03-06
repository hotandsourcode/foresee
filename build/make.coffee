require 'shelljs/make'
fs = require 'fs'

#Configs
config = {
      srcDir: "src"
    , testDir: "test"
    , webtestDir: "webtest"
    , browsertestDir: "browsertest"
    , buildDir: "build"
    , globalReqs: {"coffee":"coffee-script", "mocha":"mocha", "nodemon":"nodemon"}
    , providedReqs: ["java"]
}

#Helpers
isRootInUbuntu = -> exec("whoami", {silent:true}).output == 'root'
needsSudo = -> (process.platform == 'linux') && (exec("hostname", {silent:true}).output.indexOf('c9-node') == -1) #detects if we are on cloud9
isEnoughPriv =  -> ( !needsSudo() || isRootInUbuntu() )

globalPkgInstallCommand = (pkg, withSudo) -> (if(withSudo) then "sudo " else "") + "npm install #{pkg} -g"


#Tasks
mocha = (reporter="spec", testDir="#{config.testDir}", timeout=1000) ->
  "mocha --reporter #{reporter} --compilers coffee:coffee-script --colors #{testDir}/ -t #{timeout} | tee junit.xml"

target.all = ->
  target.dev()

target.ensureProvidedReqs = ->
  notInstalled = config.providedReqs.filter( (item) -> not which(item) )
  notInstalled.forEach( (item) -> echo("Please make sure that #{item} is properly installed.") )

  if(notInstalled.length > 0)
    exit(1)

target.ensureGlobalReqs = ->
  notInstalledKeys = (k for k,v of config.globalReqs when not which(k))
  if(notInstalledKeys.length > 0)
    if(!isEnoughPriv())
      echo("Does not have enough priviledge to install global packages")
      echo("Please run 'sudo ./run ensureGlobalReqs' to install needed global pkgs")
      exit(1)

    exec(globalPkgInstallCommand(config.globalReqs[k], needsSudo())) for k in notInstalledKeys

target.npmInstall = ->
  exec("npm install")

target.ensureReqs = ->
  target.ensureProvidedReqs()
  target.ensureGlobalReqs()
  target.npmInstall()

target.autotest = ->
  target.ensureReqs()
  scripts = "
require('shelljs/global');\n
\n
console.log('\\033[2J\\033[0f'); //Clear Screen\n
console.log('Restarting autotest...');\n
\n
exec('#{mocha("min")}');\n
  "
  fs.writeFileSync("#{config.buildDir}/autotest.js", scripts)

  exec("nodemon --watch #{config.srcDir} --watch #{config.testDir} -e js,coffee #{config.buildDir}/autotest.js")

target.dev = ->
  target.ensureReqs()
  exec("nodemon --watch #{config.srcDir} -e js,coffee app.js")

target.test = ->
  target.ensureReqs()
  exec("#{mocha("xunit")}")

target.webtest = ->
  target.ensureReqs()
  exec("#{mocha("spec", config.webtestDir, 30000)}")

target.browsertest = ->
  target.ensureReqs()
  exec("coffee -c -o #{config.browsertestDir}/.js/ -w -m #{config.browsertestDir}/ assets/js/")

target.webtest_xvfb = ->
  target.ensureReqs()
  #This will only work with ubuntu with xvfb
  if(not which("xvfb-run"))
    echo "Please ensure that xvfb-run is properly installed."
    exit(1)

  exec("xvfb-run #{mocha("spec", config.webtestDir, 30000)}")

target.test_on_jenkins = ->
  target.test()
  #Browser tests when ready !!
  target.webtest_xvfb()


