//  Copyright © 2017 Artifex Software Inc. All rights reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ARDKDocumentSettings;

/// Delegate protocol used to notify other classes about user accessing disabled features
@protocol ARDKDocumentSettingsFeatureDelegate <NSObject>
@optional
/// Callback triggered when the user wants to access disabled features
- (void)ardkDocumentSettings:(ARDKDocumentSettings* _Nonnull)documentsSettings pressedDisabledFeature:(UIView* _Nonnull)sourceView atPosition:(CGPoint) position;
/// Callback triggered when the sodk did show disabled features (like a tab), useful for customization
- (void)ardkDocumentSettings:(ARDKDocumentSettings* _Nonnull)documentsSettings didDisplayDisabledFeatures:(NSArray<UIButton *> * _Nonnull)buttons;
@end

/// Allow various functionality within SmartOffice to be enabled/disabled
///
/// This is typically used to prevent data leakage.
///
/// By default, everything is disabled.
///
/// As well as the settings here, see 'saveAsHandler',
/// 'saveToHandler' and 'savePdfHandler'
/// and the ARButtonHandler, which are used to enable other UI features.
@interface ARDKDocumentSettings : NSObject<NSCoding>

@property (nonatomic, weak) id<ARDKDocumentSettingsFeatureDelegate> _Nullable featureDelegate;

/// Whether the save button appears on the document File ribbon
@property (nonatomic) BOOL saveButtonEnabled;

/// Whether the 'save to' button appears on the document File ribbon
@property (nonatomic) BOOL saveToButtonEnabled;

/// Whether document editing is enabled
@property (nonatomic) BOOL editingEnabled;

/// Whether the user is allowed to print documents
@property (nonatomic) BOOL printingEnabled;

/// Whether the user is allowed to securely print documents
@property (nonatomic) BOOL securePrintingEnabled;

/// Whether the user is allowed to insert photos from the camera into documents
@property (nonatomic) BOOL insertFromCameraEnabled;

/// Whether the user is allowed to insert images from the gallery into documents
@property (nonatomic) BOOL insertFromPhotosEnabled;

/// Whether the user is allowed to edit PDF annotations
@property (nonatomic) BOOL pdfAnnotationsEnabled;

/// Whether the user is allowed to perform PDF redaction
@property (nonatomic) BOOL pdfRedactionEnabled;

/// Whether the user is allowed to fill PDF forms
@property (nonatomic) BOOL pdfFormFillingEnabled;

/// Whether the app should show PDF forms filling options
@property (nonatomic) BOOL pdfFormFillingAvailable;

/// Whether the app should show PDF redaction options
@property (nonatomic) BOOL pdfRedactionAvailable;

/// Whether the user is allowed to sign PDF forms
@property (nonatomic) BOOL pdfFormSigningEnabled;

/// Whether the user is allowed to create signature fields
@property (nonatomic) BOOL pdfSignatureFieldCreationEnabled;

/// Whether full-screen mode is supported
@property (nonatomic) BOOL fullScreenModeEnabled;

/// Whether dark-mode affects document content
@property (nonatomic) BOOL contentDarkModeEnabled;

/// The date and time after which the document may no longer be viewed or
/// edited, the document is closed as the default action when expires.
/// If expiresPromptBlock property is set then the block is called instead of
/// closing the document
@property (nonatomic) NSDate * _Nullable expiresDate;

/// A block to prompt the app to close the document.
/// If this is set, it is called instead of closing the document when the time
/// expires and if closeDocBlock is called then the document is closed
@property (nonatomic, copy, nullable)
        void (^expiresPromptBlock)(UIViewController * _Nonnull presentingVc,
                                   BOOL                        docHasBeenModified,
                                   void                        (^ _Nullable closeDocBlock)(void));

/// Tells whether it has expired
/// - YES if expiresDate is set and expired
@property (nonatomic, readonly) BOOL expired;

/// Use this to enable or disable all settings
- (void)enableAll:(BOOL)enable;

@end
