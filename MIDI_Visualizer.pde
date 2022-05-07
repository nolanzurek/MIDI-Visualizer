import javax.sound.midi.*;
import java.util.*;
import java.io.File;
import com.hamoid.*;

// fluidsynth -F "$var".wav Soundfont.sf2 "$var".mid
// fluidsynth tutorial

VideoExport videoExport;
Sequencer sequencer;

boolean renderMode = false;
boolean tempoFlag = true;

ArrayList<Note> notes = new ArrayList<Note>();

String[] notesLookup = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"};

// inputs and stuff
String midiPath = "C:/Users/nolan/Downloads/HamSY08.MID";
String fluidSynthExecutablePath = "C:/Users/nolan/Downloads/fluidsynth-2.2.6-win10-x64/bin/fluidsynth.exe";
String audioOutputPath = "C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/output.wav";
String soundFrontPath = "C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/data/Nice-Steinway-Lite-v3.0.sf2";

// PImage concrete = new PImage();

// long currentTick = -width*2*3*10;
double currentTick = 0;
double offset = 0;
float TPP = 20;    // ticks per pixel
int fps = 30;
float tempo = 80;  // get the tempo from the MIDI data
color backgroundColor = #222222;
double ticksPerFrame;
long lastTick = 0;

public static byte[] hexStringToByteArray(String s) {
    int len = s.length();
    byte[] data = new byte[len / 2];
    for (int i = 0; i < len; i += 2) {
        data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                             + Character.digit(s.charAt(i+1), 16));
    }
    return data;
}

void setup() {
  
  if(args != null) {
    midiPath = args[0];
  }
  
  blendMode(ADD);
  
  //sync the live output with the video output
  frameRate(fps);
  videoExport = new VideoExport(this, "Render of " + midiPath.split("/")[midiPath.split("/").length - 1].substring(0, midiPath.split("/")[midiPath.split("/").length - 1].length() - 4) + ".mov");
  videoExport.setFrameRate(fps);  
  videoExport.startMovie();
  
  if(renderMode) {
    frameRate(100000);   //as many fps as possible
    //command: calling fluidsynth to convert the MIDI file into a .wav audio file
    launch(fluidSynthExecutablePath + " -F " + "\"" + audioOutputPath + "\"" + " " + "\"" + soundFrontPath + "\" \"" + midiPath + "\" -g 1");
    //this audio file will be synchronized with the video output
    videoExport.setAudioFileName(audioOutputPath);
  }
  
  
  
  // concrete = loadImage("data/Procedural Concrete Texture Dark.png");
  
  // iterate through notes, make list with all start and end times from the notes
  // (all of the points where the harmony changes)  
  // calculate the chord at each list (using ChordCalculator), save the sequence of chords to a list
  // in the draw look
      // if the current tick is a tick where the harmony changes
      // display the corresponding chord at that tick 
          // use a hashmap to do this
          // implement as a list with a counter that counts each time the harmony changes for further optimization
  
  colorMode(HSB, 360);

  try {
    
         
         sequencer = MidiSystem.getSequencer();
         if (sequencer == null) {
             println("sequencer is null :(");
         } else {
             sequencer.open();
         }
         File myMidiFile = new File(midiPath);
         Sequence mySeq = MidiSystem.getSequence(myMidiFile);
         sequencer.setSequence(mySeq);
         
         
         // which tracks have instruments???
         // I'm not knowledgeable enough to write a program to tell this yet
         // however
         // most downloaded midi recordings have a single track with the piano part in it
         // As such, mainTrack should be defined as mySeq.getTracks()[0]
         // the tracks recorded from my electric piano have a two tracks: a tempo track first, then the actual piano track
         // As such, mainTrack should be defined as mySeq.getTracks()[1]
         // if you keep running into an array out of bounds exception, it might be because
             // you're trying a access a track that isn't there
         // if the code compiles but the visualizer is blank, it may be because it's drawing
             // a tempo or info track to the screen, instead of the actual music
         
         ArrayList<MidiEvent> workingME = new ArrayList<MidiEvent>();
         
         for(int j = 0; j < mySeq.getTracks().length; j++) {
           Track mainTrack = mySeq.getTracks()[j];
           
           for(int i = 0; i < mainTrack.size(); i++) {
             if((mainTrack.get(i).getMessage().getStatus() == 128 || mainTrack.get(i).getMessage().getStatus() == 144)) {
               workingME.add(mainTrack.get(i));
             } else if(mainTrack.get(i).getMessage() instanceof MetaMessage) {
               MetaMessage temp = (MetaMessage)mainTrack.get(i).getMessage();
               byte[] data = temp.getData();
               if (temp.getType() != 81 || data.length != 3 || !tempoFlag) {
              } else {
                println("we have a tempo marking at place " + i + " of " + mainTrack.size());
                println(data);
                int mspq = ((data[0] & 0xff) << 16) | ((data[1] & 0xff) << 8) | (data[2] & 0xff);
                int tempo_here = Math.round(60000001f / mspq);
                tempo  = tempo_here;
                tempoFlag = false;
                /*
                long tempmus = round(60000000*((float)1/tempo));
                String hexString = String.format("%06x", tempmus);
                println(hexString);
                println(hexString.substring(0, 2));
                println(hexString.substring(2, 4));
                println(hexString.substring(4, 6));
                ((MetaMessage)tempoTrack.get(i).getMessage()).setMessage(81, hexStringToByteArray(hexString), 3);
                println(temp.getData());
                */
                
              }
           }
         
           
             
           }
           
           
         }
         
         
         println("This MIDI file contains " + mySeq.getTracks().length + " tracks");
         println("Beat length in milliseconds: " + mySeq.getResolution());
         println("Milliseconds per tick: " + (float)60000/(tempo * mySeq.getResolution()));
         println("Ticks per second::" + 1/(0.001 * (float)60000/(tempo * mySeq.getResolution())));
         println("Ticks per frame: " + (1/(0.001 * (float)60000/(tempo * mySeq.getResolution())))/fps);
         ticksPerFrame = (1/(0.001 * (float)60000/(tempo * mySeq.getResolution())))/fps;

         while(workingME.size() != 0) {
           
            for(int i = 0; i < workingME.size(); i++) {
               if((workingME.get(0).getMessage().getMessage()[1] == workingME.get(i).getMessage().getMessage()[1]) &&
                  (workingME.get(0).getMessage().getStatus() == 144) &&
                  (workingME.get(i).getMessage().getStatus() == 128)) {
                  notes.add(new Note(
                     workingME.get(0).getMessage().getMessage()[0],
                     workingME.get(0).getMessage().getMessage()[1],
                     workingME.get(0).getMessage().getMessage()[2],
                     workingME.get(0).getTick(),
                     workingME.get(i).getTick()
                  ));
                  workingME.remove(i);
                  workingME.remove(0);
                  
                  break;
               }
            }
         }

      } catch (Exception e) {
         println(e + "shet");
         println("test");
      }
      
   // MIDI sound setup
   
   if(!renderMode) {
       try {
       File sf = new File(dataPath(soundFrontPath));
       Soundbank soundbank = MidiSystem.getSoundbank(sf);
       Synthesizer synth = MidiSystem.getSynthesizer();
       synth.loadAllInstruments(soundbank);
       synth.open();
       
       //open the sequencer here??
       
     } catch (Exception e) {
       println(e.getMessage());
     }
     
     try {
       sequencer.setTempoInBPM(tempo);
       sequencer.start();
     } catch (Exception e) {
       println(e.getMessage());
     }
  }
   
   for(int i = notes.size()-1; i > 0; i--) {
     if(notes.get(i).endTick >= lastTick) {
       lastTick = notes.get(i).endTick;
     }
   }
   
   size(1440, 810);
   strokeWeight(2);
  
}

void draw() {
  
  // move max and min pitch outside the draw loop for optimization
  
  int maxPitch = 0;
  for(int i = 0; i < notes.size(); i++) {
    if(notes.get(i).pitch > maxPitch) {maxPitch = notes.get(i).pitch;}
  }
  
  int minPitch = 127;
  for(int i = 0; i < notes.size(); i++) {
    if(notes.get(i).pitch < minPitch) {minPitch = notes.get(i).pitch;}
  }
  
  background(backgroundColor);
  
  // 10 ticks per pixel
  // make this value changeable
  
  
  
  offset = -currentTick/TPP;
  
  List<String> curNotes = new ArrayList<String>();

  float visibleTickRadius = 0.5*width*TPP;
  for(int i = 0; i < notes.size(); i++) {
    
    // change bounds of "search area" to include every note that is on the screen
        // currentTick >= cur.startTick + {offset thing idk}
        // have a further conditioanl that breaks the loop if the start tick comes after the biggest rendered tick
        // have a further conditioanl that removes an item from notes if it ends before the first tick rendered
    // inside of that conditional, have the normal one that bolds the rectangle
  
    Note cur = notes.get(i);
    if(cur.startTick <= currentTick + visibleTickRadius && cur.endTick >= currentTick - visibleTickRadius) {
      fill((((cur.pitch)*7)%12)*30, 360, 360, 210);
      if((currentTick >= cur.startTick) && (currentTick <= cur.endTick)) {stroke(255); /* curNotes.add(notesLookup[(cur.pitch)%12]); */} else {noStroke();}
      rect((float)(offset + (double)cur.startTick/TPP + width/2), map(cur.pitch, minPitch-2, maxPitch+2, height, 0), (float)cur.length/TPP, 2*height/(maxPitch - minPitch));
    } else if (cur.startTick > currentTick + visibleTickRadius) {
      break;
    }
    
    // if we are done, end it
    
    
/*    
    
    try {

      // text(calc.getChord(curNotes).toString(), 100, 400);
      println(calc.getChord(curNotes));
    
  } catch (Exception e) {
  
      println("no notes lmao");
    
  }
  
  */
    
  }
  
  if(currentTick > lastTick + visibleTickRadius) {
      println("rendering...");
      //launch("C:/Users/nolan/Downloads/fluidsynth-2.2.6-win10-x64/bin/fluidsynth.exe -F C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/output.wav C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/data/Nice-Steinway-Lite-v3.0.sf2 \"" + midiPath + "\" -g 2");
      videoExport.setAudioFileName(audioOutputPath);
      videoExport.saveFrame();
      exit();
    }
  
  // for rendering: apply concrete image directly
  // image(concrete, 0, 0);
  
  
  //OLD - works, but will get (very slowly) less accurate (laggy) over time
  //currentTick += ticksPerFrame;
  
  //NEW - Consistant
  currentTick = frameCount*ticksPerFrame;
  
  videoExport.saveFrame();
  
  //noLoop();
  
}

void keyPressed () {

  if(key == ' ') {
    
    videoExport.saveFrame();
    exit();
    
  }
  
}
