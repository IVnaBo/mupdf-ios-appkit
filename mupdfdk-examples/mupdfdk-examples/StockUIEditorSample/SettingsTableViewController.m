//
//  SettingsTableViewController.m
//  smart-office-examples
//
//  Created by Joseph Heenan on 27/03/2017.
//  Copyright © 2017 Artifex. All rights reserved.
//

#import "SettingsTableViewController.h"
#import <objc/runtime.h>

@interface SettingsTableViewController ()
@property (nonatomic,readonly) NSDictionary *settingsProperties;
@end

@implementation SettingsTableViewController
{
    NSDictionary *_settingsProperties;
}

/**
 * Get a name for an Objective C property
 *
 */
- (NSString *)propertyTypeStringOfProperty:(objc_property_t) property {
    NSString *attributes = @(property_getAttributes(property));

    if ([attributes characterAtIndex:0] != 'T'
        || [attributes characterAtIndex:1] == '@') // We ignore properties of object type
        return nil;

    switch ([attributes characterAtIndex:1])
    {
        case 'B':
            return @"BOOL";
        case 'c':
            // iOS 9 returns this for BOOL
            return @"char";
    }

    assert(!"Unimplemented attribute type");
    return nil;
}

/**
 * Get a name->type mapping for an Objective C class
 *
 * Loosely based on http://stackoverflow.com/questions/754824/get-an-object-properties-list-in-objective-c
 *
 * See 'Objective-C Runtime Programming Guide', 'Declared Properties' and
 * 'Type Encodings':
 *   https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html#//apple_ref/doc/uid/TP40008048-CH101
 *   https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1
 *
 * @returns (NSString) Dictionary of property name --> type
 */

- (NSDictionary *)propertyTypeDictionaryOfClass:(Class)klass {
    NSMutableDictionary *propertyMap = [NSMutableDictionary dictionary];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(klass, &outCount);
    for(i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName && strcmp(propName, "featureDelegate") != 0)
        {
            propertyMap[@(propName)] = [self propertyTypeStringOfProperty:property];
        }
    }
    free(properties);
    return propertyMap;
}

- (NSDictionary *)settingsProperties
{
    if (!_settingsProperties)
    {
        Class class = _settings.class;
        NSMutableDictionary *propertyMap = [[NSMutableDictionary alloc] init];

        do
        {
            [propertyMap addEntriesFromDictionary:[self propertyTypeDictionaryOfClass:class]];
        }
        while ((class = class.superclass) != NSObject.class);

        _settingsProperties = propertyMap;
    }

    return _settingsProperties;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settingsProperties.count + 1;
}

enum
{
    ViewTag_Label = 1,
    ViewTag_Switch = 2
};

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"toggle" forIndexPath:indexPath];
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];

    UILabel *label = (UILabel *) [cell viewWithTag:ViewTag_Label];
    UISwitch *uiSwitch = (UISwitch *) [cell viewWithTag:ViewTag_Switch];

    NSArray *sortedKeys = [[self.settingsProperties allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSString *propertyName = sortedKeys[indexPath.row - 1];

    label.text = propertyName;

    NSNumber *state = [_settings valueForKey:propertyName];
    uiSwitch.on = state.boolValue;

    /* this looks slightly odd; if forces the switch press to be handled as a
     * press on the cell instead. */
    uiSwitch.userInteractionEnabled = NO;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0)
    {
        [_settings enableAll:!_settings.editingEnabled];
        [tableView reloadData];
        return;
    }

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    UISwitch *uiSwitch = (UISwitch *) [cell viewWithTag:ViewTag_Switch];

    NSArray *sortedKeys = [[self.settingsProperties allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSString *propertyName = sortedKeys[indexPath.row - 1];
    NSNumber *state = [_settings valueForKey:propertyName];

    [_settings setValue:[NSNumber numberWithBool:!state.boolValue] forKey:propertyName];
    [uiSwitch setOn:!state.boolValue animated:YES];
}


@end
