#ifndef SOUND_MANAGER_H
#define SOUND_MANAGER_H

#import "ObjectAL.h"

#include "MathTypes.h"
#include <map>
#include <vector>
#include <string>

class Sound
{

public:

    ALBuffer* sound;
    ALChannelSource *source;
    NSString * soundName;

    Sound( const char * filename = NULL )
    {
        source = nil;
        
        if( filename )
            Load( filename );

    }

    ~Sound()
    {
        [source stop];
        source = nil;
        sound = nil;
    }

    void Load( const char * filename )
    {
        soundName = [NSString stringWithString:[[NSString stringWithUTF8String:filename] stringByAppendingPathExtension:@"caf"]];
        sound = [[OpenALManager sharedInstance] bufferFromFile:soundName reduceToMono:NO];
        source = [ALChannelSource channelWithSources:4];
    }

    void PlayAt( const xVec3 & Pos , float volume = 1.0f , float pitch_rand = 0.0f )
    {
        if ( (!source) || (!sound) ) {
            NSLog(@"Broken sound system! [PlayAt]");
            return;
        }
        
        source.maxDistance = 512;
        source.referenceDistance = 30;
        source.pitch = 1.0f + ( rand()%200 - 100 ) * 0.01f * pitch_rand;
        source.volume = volume;
        source.position = alpoint(Pos.x, Pos.y, Pos.z);
        [source play:sound loop:NO];
    }

    void Update( xVec3 & Pos , float pitch = 1.0f )
    {
        if ( (!source) || (!sound) ) {
            NSLog(@"Broken sound system! [Update]");
            return;
        }
        
        source.position = alpoint(Pos.x, Pos.y, Pos.z);
        if( pitch != 1.0f ){
            source.pitch = pitch;
        }
    }
    
    void Stop()
    {
        if ( (!source) || (!sound) ) {
            NSLog(@"Broken sound system! [Stop]");
            return;
        }

        [source stop];
    }
};

class cSoundManager
{

public :
    
    typedef std::map< std::string , Sound * > sound_list;

    sound_list list;

    Sound * GetSound( const std::string & name , const std::string & filename = "" )
    {

        sound_list :: iterator i = list . find( name );

        if( i != list . end() )
        {
            return i -> second;
        }

        if( !filename . empty() )
        {

            Sound * s = new Sound( filename . c_str()  );
            list[ name ] = s;
            return s;
        }

        return NULL;

    }

    cSoundManager(){

    }

    ~cSoundManager()
    {

        [[OpenALManager sharedInstance] clearAllBuffers];
        
        sound_list :: iterator i = list . begin();

        while( i != list . end() )
        {

            delete i -> second;

            ++i;
        }
    
    }


};

extern cSoundManager * SoundManager;

class cListener
{

public:

    xVec3 LastPos;

    cListener()
    {

    }

    void Update( xVec3 & center , xVec3 & eye )
    {

        const xVec3 up( 0, 1, 0 );
        xVec3 forward = -center;
        forward . normalize();

        xVec3 vel = ( eye - LastPos ) / ( globalDT + 0.0001 );
        
        [OpenALManager sharedInstance].currentContext.listener.position = alpoint(eye.x,eye.y,eye.z);
        [OpenALManager sharedInstance].currentContext.listener.velocity = alvector(vel.x,vel.y,vel.z);
        [OpenALManager sharedInstance].currentContext.listener.orientation = alorientation(forward.x,forward.y,forward.z, up.x, up.y, up.z);
        
        LastPos = eye;

    }


};

extern cListener * Listener;

#endif
