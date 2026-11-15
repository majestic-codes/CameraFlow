# Security policy

CameraFlow runs inside apps with access to the camera, the location of the photos and the photo library, and it hands
the photos to the app as files. Report a vulnerability privately, so it is fixed before it is known.

## Reporting a vulnerability

Report it through GitHub's private vulnerability reporting: open the **Security** tab of the repository and choose
**Report a vulnerability**, or go straight to
[the report form](https://github.com/majestic-codes/CameraFlow/security/advisories/new). Do not open an issue, a pull
request or a discussion for it.

If the form is not there, open an issue that asks for a private way to report a vulnerability, with no details of it.

A report helps most with:

- the CameraFlow version, the iOS version and the device;
- what an attacker can do, and under which configuration of the flow;
- the steps or the code that show it.

The report and the conversation about it stay private in a draft security advisory until the maintainer publishes it
together with the fixed release.

A vulnerability of iOS itself, or of one of Apple's frameworks the package calls, is Apple's to fix: report it to
Apple.

## Supported versions

| Version | Supported |
|---|---|
| 1.x | Yes |

A fix ships in a new 1.x release: update to it.
