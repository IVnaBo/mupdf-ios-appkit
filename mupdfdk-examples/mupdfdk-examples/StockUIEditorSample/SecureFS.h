@interface SecureFS : NSObject <ARDKSecureFS>

/** Temporary path within SecureFS suitable for passing to MuPDFDK.
 * If you are not using SecureFS, you use a subdirectory of
 * NSTemporaryDirectory(). */
+ (NSString *)temporaryPath;

+ (NSString *)docsPath;

@end
