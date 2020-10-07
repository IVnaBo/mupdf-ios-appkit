This SDK consists of mupdfdk.framework and an example app. Make a copy of
mupdfdk.framework in your own app to use it there.

mupdfdk.framework includes slices for both devices and simulators. The simulator
slice needs to be removed for submissions of your app to the app store. We've
included a script named strip-frameworks.sh that performs that task. You need
simply add a Run Script phase to the end of the build to call it.

The example, although just a single app, presents 4 ways to use the SDK.

1) SimpleStockUIEditorSample - this is the simplest use case, consisting in
   creating a document view that has a built-in user interface via which
   a document can be viewed and edited. No interaction between the app and
   the view is required other than when the view is closed.

2) StockUIEditorSample - this is similar to Example 1 above, but shows how
   to configure more advanced features.

   a) Restrictions on allowed user operations.

   b) Routing all file access through an encrypting file system.

   c) Isolating cut and paste operations to within the app.

   d) Dealing with local copies of remote files with control of
      copy back on completion.

3) CustomUIEditorSample - this shows how to create your own UI and have it
   present and interact with a document view so as to implement all the
   features available with our stock UI.

4) ConvertToPNGSample - this demonstrates the use of lower-level methods
   that load pages of a document and can render them to bitmaps.

Licensing: https://mupdf.com/license.html

Source: http://git.ghostscript.com/?p=mupdf-ios-sdk.git
