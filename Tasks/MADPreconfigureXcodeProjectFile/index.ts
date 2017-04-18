/// <reference path="./typings/globals/q/index.d.ts" />
/// <reference path="./typings/globals/node/index.d.ts" />
import tl = require('vsts-task-lib/task')
let Xcode = require('xcode-node').default;

const run = () => {
  try {
    // Get all variables
    const configuration = tl.getInput('ConfigurationName', true);
    const filePathGlob = tl.getInput('FilePath', true);
    const productBundleIdentifier = tl.getInput('ProductBundleIdentifier', true);
    const productName = tl.getInput('ProductName', true);
    const ensureProvisioningStyleManual = tl.getBoolInput('ensureProvisioningStyleManual');
    // Paths
    const workingDir = tl.getPathInput('cwd');
    const fileMatches = tl.findMatch(
      workingDir,
      filePathGlob,
      {
        followSymbolicLinks: false,
        followSpecifiedSymbolicLink: false,
      });
    // modify project files
    fileMatches.forEach((path) => {
      const project = new Xcode(path);
      project.getTargets().forEach((target) => {
        project.configuration.setUserDefinedTargetConfiguration(
          target.name,
          configuration,
          'PRODUCT_BUNDLE_IDENTIFIER',
          productBundleIdentifier);

        project.configuration.setUserDefinedTargetConfiguration(
          target.name,
          configuration,
          'PRODUCT_NAME',
          productName);
      });

      if(ensureProvisioningStyleManual) {
        tl.debug("Ensures that ProvisionStyle is set to Manual");
        project.myProj.addTargetAttribute("ProvisioningStyle", "Manual");
      }

      project.save();
    });
  } catch (err) {
    tl.setResult(tl.TaskResult.Failed, err);
  }
};

run();
