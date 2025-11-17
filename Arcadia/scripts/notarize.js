
const { notarize } = require("electron-notarize");

exports.default = async function notarizeHook(context) {
  const { electronPlatformName, appOutDir } = context;
  if (electronPlatformName !== "darwin") return;

  const appName = context.packager.appInfo.productFilename;
  const appPath = `${appOutDir}/${appName}.app`;

  if (!process.env.APPLE_ID || !process.env.APPLE_ID_PASSWORD) {
    console.warn("APPLE_ID or APPLE_ID_PASSWORD not set — skipping notarization.");
    return;
  }

  console.log("Notarizing", appPath);
  await notarize({
    appBundleId: "com.arcadia.app",
    appPath,
    appleId: process.env.APPLE_ID,
    appleIdPassword: process.env.APPLE_ID_PASSWORD
  });
  console.log("Notarization finished.");
};
