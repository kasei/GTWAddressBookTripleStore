#include <CommonCrypto/CommonDigest.h>
#import "GTWAddressBookTripleStore.h"
#import <GTWSWBase/GTWIRI.h>
#import <GTWSWBase/GTWLiteral.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWBlockEnumerator.h>

static id<GTWTriple> propertyTriple (ABPerson* person, GTWIRI* subject, NSString* property, GTWIRI* predicate, Class class, id<GTWTerm>* object) {
    id<GTWTriple> t    = [[GTWTriple alloc] init];
    t.subject       = subject;
    t.predicate     = predicate;
    
    id value        = [person valueForProperty:property];
    if (value) {
        t.object        = [[class alloc] initWithValue:value];
        if (object)
            *object = t.object;
        return t;
    } else {
        if (object)
            *object = nil;
        return nil;
    }
}

static NSArray* propertyTriples (ABPerson* person, GTWIRI* subject, NSString* property, GTWIRI* predicate, Class class, NSString* (^convert)(NSString* value)) {
    NSMutableArray* array   = [NSMutableArray array];
//    id<GTWTriple> t    = [[GTWTriple alloc] init];
//    t.subject       = subject;
//    t.predicate     = predicate;
    
    ABMultiValue* values        = [person valueForProperty:property];
    for (id ident in values) {
        NSString* value  = [values valueForIdentifier:ident];
        if (convert) {
            value   = convert(value);
        }
        if (value) {
            id<GTWTriple> t    = [[GTWTriple alloc] initWithSubject:subject predicate:predicate object:[[class alloc] initWithValue:value]];
            [array addObject:t];
        }
    }
    return array;
}

static NSUInteger emitProperties (ABPerson* person, GTWIRI* subject, NSString* property, GTWIRI* predicate, Class class, void (^block)(id<GTWTriple> t), NSString* (^convert)(NSString* value)) {
    id<GTWTriple> t    = [[GTWTriple alloc] init];
    t.subject       = subject;
    t.predicate     = predicate;
    
    ABMultiValue* values        = [person valueForProperty:property];
    NSUInteger count    = 0;
    for (id ident in values) {
        NSString* value  = [values valueForIdentifier:ident];
        if (convert) {
            value   = convert(value);
        }
        if (value) {
            t.object        = [[class alloc] initWithValue:value];
            block(t);
            count++;
        }
    }
    return count;
}


@implementation GTWAddressBookTripleStore

+ (unsigned)interfaceVersion {
    return 0;
}

+ (NSString*) usage {
    return @"{}";
}

+ (NSDictionary*) classesImplementingProtocols {
    NSSet* set  = [NSSet setWithObjects:@protocol(GTWTripleStore), nil];
    return @{ (id)self: set };
}

+ (NSSet*) implementedProtocols {
    return [NSSet setWithObjects:@protocol(GTWTripleStore), nil];
}

- (instancetype) initWithDictionary: (NSDictionary*) dictionary {
    return [self init];
}

- (GTWAddressBookTripleStore*) init {
    if (self = [super init]) {
        self.ab = [ABAddressBook sharedAddressBook];
        if (!self.ab)
            return nil;
    }
    return self;
}

- (NSArray*) getTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
    NSMutableArray* triples = [NSMutableArray array];
    [self enumerateTriplesMatchingSubject:s predicate:p object:o usingBlock:^(id<GTWTriple> t) {
        [triples addObject:t];
    } error:error];
    return triples;
}

- (BOOL) enumerateTriplesWithBlock: (void (^)(id<GTWTriple> t)) block error: (NSError**) error {
    NSError* _error = nil;
    NSEnumerator* e    = [self tripleEnumeratorMatchingSubject:nil predicate:nil object:nil error:&_error];
    if (_error) {
        if (error) {
            *error  = _error;
        }
        return NO;
    }
    for (id r in e) {
        block(r);
    }
    return YES;
}

- (BOOL) enumerateTriplesMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o usingBlock: (void (^)(id<GTWTriple> t)) block error:(NSError **)error {
    return [self enumerateTriplesWithBlock:^(id<GTWTriple> t){
        if (s && !([s isKindOfClass:[GTWVariable class]])) {
            if (![s isEqual:t.subject])
                return;
        }
        if (p && !([p isKindOfClass:[GTWVariable class]])) {
            if (![p isEqual:t.predicate])
                return;
        }
        if (o && !([o isKindOfClass:[GTWVariable class]])) {
            if (![o isEqual:t.object])
                return;
        }
        //        NSLog(@"enumerating matching quad: %@", q);
        block(t);
    } error: error];
}

- (NSEnumerator*) tripleEnumeratorMatchingSubject: (id<GTWTerm>) s predicate: (id<GTWTerm>) p object: (id<GTWTerm>) o error:(NSError **)error {
//    NSArray* triples    = [self getTriplesMatchingSubject:s predicate:p object:o error:error];
//    return [triples objectEnumerator];
    if (p && [p isKindOfClass:[GTWIRI class]]) {
        NSSet* recognized   = [NSSet setWithObjects:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type", @"http://xmlns.com/foaf/0.1/name", @"http://xmlns.com/foaf/0.1/familyName", @"http://xmlns.com/foaf/0.1/givenName", @"http://xmlns.com/foaf/0.1/nick", @"http://xmlns.com/foaf/0.1/homepage", @"http://xmlns.com/foaf/0.1/mbox_sha1sum", nil];
        if (![recognized containsObject:p.value]) {
            return [@[] objectEnumerator];
        }
    }
    
    NSDictionary* propertyPredicates    = @{
                                            //                                            kABFirstNameProperty: @"http://xmlns.com/foaf/0.1/givenName",
                                            //                                            kABLastNameProperty: @"http://xmlns.com/foaf/0.1/familyName",
                                            kABNicknameProperty: @{@"url": @"http://xmlns.com/foaf/0.1/nick", @"type": [GTWLiteral class]},
                                            };
    NSDictionary* multiPropertyPredicates    = @{
                                                 kABURLsProperty: @{@"url": @"http://xmlns.com/foaf/0.1/homepage", @"type": [GTWIRI class]},
                                                 kABHomePageProperty: @{@"url": @"http://xmlns.com/foaf/0.1/homepage", @"type": [GTWIRI class]},
                                                 kABEmailProperty: @{@"url": @"http://xmlns.com/foaf/0.1/mbox_sha1sum", @"type": [GTWLiteral class], @"convert": ^(NSString* value){
                                                     NSString* mbox = [NSString stringWithFormat:@"mailto:%@", value];
                                                     NSData *data = [mbox dataUsingEncoding:NSUTF8StringEncoding];
                                                     uint8_t digest[CC_SHA1_DIGEST_LENGTH];
                                                     CC_SHA1(data.bytes, (unsigned int) data.length, digest);
                                                     NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
                                                     for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
                                                         [output appendFormat:@"%02x", digest[i]];
                                                     }
                                                     //                                                     NSLog(@"%@ -> %@", output, mbox);
                                                     return output;
                                                 }},
                                                 };
    
    
    NSArray* people = [self.ab people];
    GTWIRI* foafPerson  = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/Person"];
    GTWIRI* foafname  = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/name"];
    GTWIRI* foaflname  = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/familyName"];
    GTWIRI* foaffname  = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/givenName"];
    //    GTWIRI* foafnick   = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/nick"];
    //    GTWIRI* foafhomepage   = [[GTWIRI alloc] initWithValue:@"http://xmlns.com/foaf/0.1/homepage"];
    GTWIRI* rdftype = [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    
    NSMutableArray* buffer  = [NSMutableArray array];
    NSEnumerator* peopleenum    = [people objectEnumerator];
    
    GTWProducer prod    = ^id(void){
        while (YES) {
            if ([buffer count]) {
                id obj  = [buffer lastObject];
                [buffer removeLastObject];
                return obj;
            }
            ABPerson* p = [peopleenum nextObject];
            if (!p)
                return nil;
            NSString* uid   = [p uniqueId];
            NSString* uri   = [NSString stringWithFormat:@"tag:kasei.us,2013-05-12:%@", uid];
            GTWIRI* person  = [[GTWIRI alloc] initWithValue:uri];
            
            int showAsFlags = [[p valueForProperty:kABPersonFlags] intValue] & kABShowAsMask;
            //        NSLog(@"person as company: %d", showAsFlags);
            if (!(showAsFlags & kABShowAsCompany)) {
                id<GTWTriple> t;
                id<GTWTerm> fname, lname;
                t    = [[GTWTriple alloc] initWithSubject:person predicate:rdftype object:foafPerson];
                
                if (t)
                    [buffer addObject:t];
                
                t   = propertyTriple(p, person, kABFirstNameProperty, foaffname, [GTWLiteral class], &fname);
                if (t)
                    [buffer addObject:t];

                t   = propertyTriple(p, person, kABLastNameProperty, foaflname, [GTWLiteral class], &lname);
                if (t)
                    [buffer addObject:t];

                for (NSString* property in propertyPredicates) {
                    NSDictionary* data  = propertyPredicates[property];
                    NSString* url   = data[@"url"];
                    Class class     = data[@"type"];
                    
                    t   = propertyTriple(p, person, property, [[GTWIRI alloc] initWithValue:url], class, nil);
                    if (t)
                        [buffer addObject:t];
                }
                for (NSString* property in multiPropertyPredicates) {
                    NSDictionary* data  = multiPropertyPredicates[property];
                    NSString* url   = data[@"url"];
                    Class class     = data[@"type"];
                    
                    NSArray* triples   = propertyTriples(p, person, property, [[GTWIRI alloc] initWithValue:url], class, data[@"convert"]);
                    for (id t in triples) {
                        [buffer addObject:t];
                    }
                }
                
                if (fname && lname) {
                    [buffer addObject: [[GTWTriple alloc] initWithSubject:person predicate:foafname object:[[GTWLiteral alloc] initWithValue:[NSString stringWithFormat:@"%@ %@", fname.value, lname.value]]]];
                }
                
                //            if (!(fname || lname)) {
                //                NSLog(@"person without name or nick: %@", p);
                //            }
            }
        }
        return nil;
    };
    return [[GTWBlockEnumerator alloc] initWithBlock:prod];
}

@end
