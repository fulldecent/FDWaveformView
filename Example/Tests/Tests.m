//
//  FDWaveformViewTests.m
//  FDWaveformViewTests
//
//  Created by William Entriken on 03/16/2015.
//  Copyright (c) 2014 William Entriken. All rights reserved.
//

SpecBegin(InitialSpecs)


describe(@"these will pass", ^{
    
    it(@"can do maths", ^{
        expect(1).beLessThan(23);
    });
    
    it(@"can read", ^{
        expect(@"team").toNot.contain(@"I");
    });
});

SpecEnd
