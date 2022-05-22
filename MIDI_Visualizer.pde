import javax.sound.midi.*;
import java.util.*;
import java.io.File;
import com.hamoid.*;

VideoExport videoExport;
Sequencer sequencer;

//USER SETTINGS

//if render mode is true, the MIDI visualization will be rendered to video
//otherwise, the visualization will play in real time
boolean renderMode = true;
//if text mode is enabled, note labels will be drawn beside notes
boolean textMode = true;
//if fifths mode is enabled, the notes will be colored along the circle of fifths
//otherwise, they will be colored by track
boolean fifthsMode = true;
//ticks per pixel
float TPP = 5;
//frames per second
int fps = 30;
//background color of the visualization
color backgroundColor = #222222;

//IO and dependencies

//path of the MIDI file used to generate the visualization
String midiPath = "C:/path/to/myMidiFile.mid";
//path of fluidsynth executable
//if fluidsynth is an environment variable, this can simply be "fluidsynth"
String fluidSynthExecutablePath = "C:/path/to/fluidsynth.exe";
//path of the temporary audio generated from the MIDI file
String audioOutputPath = "C:/path/to/output.wav";
//path to soundfront library used to create the audio
String soundFrontPath = "C:/path/to/mySoundFrontFile.sf2";

//GLOBAL VARIABLES
//do not touch these!
ArrayList<Note> notes = new ArrayList<Note>();  //contains all Note objects derived from MIDI file
String[] notesLookup = {"C", "C\u266F", "D", "E\u266D", "E", "F", "F\u266F", "G", "A\u266D", "A", "B\u266D", "B"};
boolean tempoFlag = true;
double currentTick = 0;  //current tick in the player
double offset = 0;  
float tempo = 120;  //default value
double ticksPerFrame;
long lastTick = 0;
int maxPitch = 0;
int minPitch = 127;
float visibleTickRadius;
float h;

void setup() {
  
  //updates some processing state variables
  size(960, 540);
  blendMode(ADD);
  textAlign(LEFT, CENTER);
  frameRate(fps);
  colorMode(HSB, 360);
  strokeWeight(4);
  
  //sets up the video export
  videoExport = new VideoExport(this, "Render of " + midiPath.split("/")[midiPath.split("/").length - 1].substring(0, midiPath.split("/")[midiPath.split("/").length - 1].length() - 4) + ".mov");
  videoExport.setFrameRate(fps);  
  videoExport.startMovie();
  
  if(renderMode) {
    
    //render at as high a frame rate as possible
    frameRate(100000);
    //command: calling fluidsynth to convert the MIDI file into a .wav audio file
    launch(fluidSynthExecutablePath + " -F " + "\"" + audioOutputPath + "\"" + " " + "\"" + soundFrontPath + "\" \"" + midiPath + "\" -g 1");
    //this audio file will be synchronized with the video output
    videoExport.setAudioFileName(audioOutputPath);
    
  }
  
  //converts MIDI file into ArrayList of Note objects
  //the Java MIDI library requires this to be wrapped in a try block
  try {
    
    //creates and opens the sequencer
    sequencer = MidiSystem.getSequencer();
    if (sequencer == null) {
      println("Erorr: the sequencer is null");
    } else {
      sequencer.open();
    }
    
    //adds the imported MIDI file to the sequencer
    File myMidiFile = new File(midiPath);
    Sequence mySeq = MidiSystem.getSequence(myMidiFile);
    sequencer.setSequence(mySeq);
     
    //temporary array of MIDI events that will be used to create ArrayList of Notes 
    ArrayList<MidiEvent> workingME = new ArrayList<MidiEvent>();
   
    //loops over the sequence to inspect each track
    //gets NoteOn, NoteOff events from each track
    //gets the first tempo marking from the first track, ignores all subsequent ones
    for(int j = 0; j < mySeq.getTracks().length; j++) {
      
      //gets current track from sequence
      Track mainTrack = mySeq.getTracks()[j];
      
      //loops over the track, adds useful midi events to workingME
      for(int i = 0; i < mainTrack.size(); i++) {
        
        //if the MIDI event is NoteOn or NoteOff, add it to workingME
        //otherwise, check if it is a tempo, then act accordingly
        if((mainTrack.get(i).getMessage().getStatus() >= 128 && mainTrack.get(i).getMessage().getStatus() <= 159)) {
          
          workingME.add(mainTrack.get(i));
         
        //if it is not NoteOn/Off, check if it is a MetaMessage
        } else if(mainTrack.get(i).getMessage() instanceof MetaMessage) {
          
          MetaMessage temp = (MetaMessage)mainTrack.get(i).getMessage();
          byte[] data = temp.getData();
          
          //if the MetaMessage is a tempo change and the tempo has not already been determined,
            //set the global tempo variable as the tempo message value
          //otherwise, ignore the MetaMsaage
          if (temp.getType() == 81 && data.length == 3 && tempoFlag) {
            
            int mspq = ((data[0] & 0xff) << 16) | ((data[1] & 0xff) << 8) | (data[2] & 0xff);
            int tempo_here = Math.round(60000000f / mspq);
            tempo = tempo_here;
            tempoFlag = false;
          
          }
          
        } 
        
      }
       
      //loops through the contents of workingME and groups NoteOn and NoteOff events into single Note objects
      //used events are removed, so workingME will be empty once all the notes are paired
      while(workingME.size() != 0) {
       
        //checks each subsequent element to see if it is a match for the first event
        for(int i = 0; i < workingME.size(); i++) {
        
          //if the ith element for workingME is a match for first event,
            //create a corresponding note object and add it to the notes ArrayList
          //then, start the search over at the new first element in workingME
          if((workingME.get(0).getMessage().getMessage()[1] == workingME.get(i).getMessage().getMessage()[1]) &&
          (workingME.get(0).getMessage().getStatus() >= 144) &&
          (workingME.get(i).getMessage().getStatus() < 144 &&
          workingME.get(0).getMessage().getStatus() - workingME.get(i).getMessage().getStatus() == 144 - 128)) {
            
            notes.add(new Note(
             workingME.get(0).getMessage().getMessage()[0],
             workingME.get(0).getMessage().getMessage()[1],
             workingME.get(0).getMessage().getMessage()[2],
             workingME.get(0).getTick(),
             workingME.get(i).getTick(), j));
            workingME.remove(i);
            workingME.remove(0);
            
            break;
          }
        
        }
      
      }
     
    }
    
    //sets the number of ticks per animation frame
    ticksPerFrame = (1/(0.001 * (float)60000/(tempo * mySeq.getResolution())))/fps;
  
    //sorts the array of Note objects by start tick
    Collections.sort(notes, new Comparator<Note>() {
      public int compare(Note s1, Note s2) {return (int)(s1.startTick - s2.startTick);}});
  
  } catch (Exception e) {
    
    println("The following exception was thrown initializing the sequencer and notes ArrayList: " + e);
    
  }
      
  //setup for the live playback of the MIDI sequence
  //this is only run if render mode is set to false, as it is not necessary for rendering
  if(!renderMode) {
   
    try {
      
      //creates and opens a synthesizer to play the MIDI file
      File sf = new File(dataPath(soundFrontPath));
      Soundbank soundbank = MidiSystem.getSoundbank(sf);
      Synthesizer synth = MidiSystem.getSynthesizer();
      synth.loadAllInstruments(soundbank);
      synth.open();
    
    } catch (Exception e) {
    
      println("The following exception was thrown initializing the synthesizer: " + e);
    
    }
  
    //starts playing the synthesizer
    //this will be synchronized with the on-screen playback
    try {
      
      sequencer.setTempoInBPM(tempo);
      sequencer.start();
    
    } catch (Exception e) {
      
      println("The following exception was thrown starting the synthesizer: " + e);
      
    }
    
  }
  
  //determines the last tick that a note is playing in the MIDI file
  for(int i = notes.size()-1; i > 0; i--) {
    if(notes.get(i).endTick >= lastTick) {
      lastTick = notes.get(i).endTick;
    }
  }
  
  //determines the highest note in the MIDI file
  for(int i = 0; i < notes.size(); i++) {
    if(notes.get(i).pitch > maxPitch) {maxPitch = notes.get(i).pitch;}
  }
  
  //determines the lowest note in the MIDI file
  for(int i = 0; i < notes.size(); i++) {
    if(notes.get(i).pitch < minPitch) {minPitch = notes.get(i).pitch;}
  }
  
  //determines the visible tick radius
    //i.e. how many ticks fit between the center and edge of the playback window
  visibleTickRadius = 0.5*width*TPP;
  
  //determines the height of one note in the visualization
  h = 2*height/(maxPitch - minPitch);
    
}

void draw() {
  
  //draws a blank background for the new frame
  background(backgroundColor);
  
  //updates the offset in order to draw the notes in the correct location
  offset = -currentTick/TPP;

  //loops over all the notes in the file and determines if they are on-screen or not
  //if they are on-screen, they are drawn
  //if they are currently sounding, they are highlighted
  for(int i = 0; i < notes.size(); i++) {
  
    Note cur = notes.get(i);
    
    //if the current note is within the range of visible ticks
    if(cur.startTick <= currentTick + visibleTickRadius && cur.endTick >= currentTick - visibleTickRadius) {
      
      //determines the fill based on the coloring mode
      if(fifthsMode) {
        
        fill((((cur.pitch)*7)%12)*30, 360, 360, 210);
        
      } else {
        
        fill(cur.track*85.2, 360, 360, 210);
        
      }
      
      //determines the note's x, y, and width values for the visualization
      float x = (float)(offset + (double)cur.startTick/TPP + width/2);
      float y = map(cur.pitch, minPitch-2, maxPitch+2, height, 0);
      float w = (float)cur.length/TPP;
      
      //if the note is currently playing, highlight it
      if((currentTick >= cur.startTick) && (currentTick <= cur.endTick)) {
        stroke(255);
      } else {
        noStroke();
      }
      
      //draws the rectangle that represents the note
      rect(x, y, w, h);
      
      //if text mode is enabled, draws the note label beside the note
      if(textMode) {
        fill(#ffffff);
        text(notesLookup[(cur.pitch)%12], x+w+5, y, width, h);
      }
      
      //otherwise, the note is not drawn and the rest of the loop is skipped
    } else if (cur.startTick > currentTick + visibleTickRadius) {
      
      //if the notes are in sorted order, we can stop drawing notes once we reach the
      //first one that is not on the screen.
      //we can do this since we sorted the list previously
      break;
      
    }
    
  }
  
  //the visualization is rendered if there are no more notes displayed on the screen
  if(currentTick > lastTick + visibleTickRadius) {  
    
    println("rendering...");
    videoExport.setAudioFileName(audioOutputPath);
    videoExport.saveFrame();
    exit();
    
  }
  
  //updates the current tick according to the number of ticks per frame
  currentTick = frameCount*ticksPerFrame;
  
  //saves the current frame to the video export
  videoExport.saveFrame();
  
}

//press the spacebar to stop the recording short
//useful for debugging
void keyPressed () {
  
  if(key == ' ') {
    videoExport.saveFrame();
    videoExport.setAudioFileName(audioOutputPath);
    exit();
  }
  
}
