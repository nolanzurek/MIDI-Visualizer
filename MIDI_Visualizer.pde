import javax.sound.midi.*;
import java.util.*;
import java.io.File;
import com.hamoid.*;

VideoExport videoExport;
Sequencer sequencer;
boolean tempoFlag = true;

//set this to true in order to render to video
//otherwise, it will simply play live
boolean renderMode = false;
//changes if the notes are colored based on the circle of fifths
boolean circleOfFifthsMode = true;

//paths to external files and applications
String midiPath = "C:/Users/nolan/Downloads/HamSY08.MID";
String fluidSynthExecutablePath = "C:/Users/nolan/Downloads/fluidsynth-2.2.6-win10-x64/bin/fluidsynth.exe";
String audioOutputPath = "C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/output.wav";
String soundFrontPath = "C:/Users/nolan/OneDrive/Documents/Processing/MIDI_Visualizer/data/Nice-Steinway-Lite-v3.0.sf2";

ArrayList < Note > notes = new ArrayList < Note > ();

double currentTick = 0;
double offset = 0;
float TPP = 20; // ticks per pixel
int fps = 30;
float tempo = 80;
color backgroundColor = #222222;
double ticksPerFrame;
long lastTick = 0;

//converts a hex string to an array of bytes (useful for adding information to MIDI file)
public static byte[] hexStringToByteArray(String s) {
  int len = s.length();
  byte[] data = new byte[len / 2];
  for (int i = 0; i < len; i += 2) {
    data[i / 2] = (byte)((Character.digit(s.charAt(i), 16) << 4) + Character.digit(s.charAt(i + 1), 16));
  }
  return data;
}

void setup() {

  if (args != null) {
    midiPath = args[0];
  }

  //this can be changed for visual effect
  blendMode(ADD);
  colorMode(HSB, 360);

  //sync the live output with the video output
  frameRate(fps);

  //setting up the video export
  videoExport = new VideoExport(this, "Render of " + midiPath.split("/")[midiPath.split("/").length - 1].substring(0, midiPath.split("/")[midiPath.split("/").length - 1].length() - 4) + ".mov");
  videoExport.setFrameRate(fps);
  videoExport.startMovie();

  //if render mode is enabled
  if (renderMode) {
    frameRate(100000); //as many fps as possible
    //command: calling fluidsynth to convert the MIDI file into a .wav audio file
    launch(fluidSynthExecutablePath + " -F " + "\"" + audioOutputPath + "\"" + " " + "\"" + soundFrontPath + "\" \"" + midiPath + "\" -g 1");
    //this audio file will be synchronized with the video output
    videoExport.setAudioFileName(audioOutputPath);
  }

  //gets all of the notes from the MIDI track
  //adds them to the Note array (with custom Note object)
  //gets tempo information from MIDI file, updates variables
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

    ArrayList < MidiEvent > workingME = new ArrayList < MidiEvent > ();

    for (int j = 0; j < mySeq.getTracks().length; j++) {
      Track mainTrack = mySeq.getTracks()[j];

      for (int i = 0; i < mainTrack.size(); i++) {
        if ((mainTrack.get(i).getMessage().getStatus() == 128 || mainTrack.get(i).getMessage().getStatus() == 144)) {
          workingME.add(mainTrack.get(i));
        } else if (mainTrack.get(i).getMessage() instanceof MetaMessage) {
          MetaMessage temp = (MetaMessage) mainTrack.get(i).getMessage();
          byte[] data = temp.getData();
          if (temp.getType() != 81 || data.length != 3 || !tempoFlag) {} else {
            println("we have a tempo marking at place " + i + " of " + mainTrack.size());
            println(data);
            int mspq = ((data[0] & 0xff) << 16) | ((data[1] & 0xff) << 8) | (data[2] & 0xff);
            int tempo_here = Math.round(60000001f / mspq);
            tempo = tempo_here;
            tempoFlag = false;

          }
        }

      }

    }

    //prints information
    println("This MIDI file contains " + mySeq.getTracks().length + " tracks");
    println("Beat length in milliseconds: " + mySeq.getResolution());
    println("Milliseconds per tick: " + (float) 60000 / (tempo * mySeq.getResolution()));
    println("Ticks per second::" + 1 / (0.001 * (float) 60000 / (tempo * mySeq.getResolution())));
    println("Ticks per frame: " + (1 / (0.001 * (float) 60000 / (tempo * mySeq.getResolution()))) / fps);
    ticksPerFrame = (1 / (0.001 * (float) 60000 / (tempo * mySeq.getResolution()))) / fps;

    //copies notes from the MIDI file into the custom Note array

    while (workingME.size() != 0) {

      for (int i = 0; i < workingME.size(); i++) {
        if ((workingME.get(0).getMessage().getMessage()[1] == workingME.get(i).getMessage().getMessage()[1]) && (workingME.get(0).getMessage().getStatus() == 144) && (workingME.get(i).getMessage().getStatus() == 128)) {
          notes.add(new Note(
          workingME.get(0).getMessage().getMessage()[0], workingME.get(0).getMessage().getMessage()[1], workingME.get(0).getMessage().getMessage()[2], workingME.get(0).getTick(), workingME.get(i).getTick()));
          workingME.remove(i);
          workingME.remove(0);

          break;
        }
      }
    }

  } catch(Exception e) {
    println(e);
    println("test");
  }

  //If we are not in render mode
  //sets up the sound playback component

  if (!renderMode) {
    try {
      File sf = new File(dataPath(soundFrontPath));
      Soundbank soundbank = MidiSystem.getSoundbank(sf);
      Synthesizer synth = MidiSystem.getSynthesizer();
      synth.loadAllInstruments(soundbank);
      synth.open();

    } catch(Exception e) {
      println(e.getMessage());
    }

    try {
      sequencer.setTempoInBPM(tempo);
      sequencer.start();
    } catch(Exception e) {
      println(e.getMessage());
    }
  }

  for (int i = notes.size() - 1; i > 0; i--) {
    if (notes.get(i).endTick >= lastTick) {
      lastTick = notes.get(i).endTick;
    }
  }

  fullScreen();
  strokeWeight(2);

}

void draw() {

  //finds the minimum and maximum pitch in the MIDI file

  int maxPitch = 0;
  for (int i = 0; i < notes.size(); i++) {
    if (notes.get(i).pitch > maxPitch) {
      maxPitch = notes.get(i).pitch;
    }
  }

  int minPitch = 127;
  for (int i = 0; i < notes.size(); i++) {
    if (notes.get(i).pitch < minPitch) {
      minPitch = notes.get(i).pitch;
    }
  }

  background(backgroundColor);

  //calculates the current offset
  offset = -currentTick / TPP;

  List < String > curNotes = new ArrayList < String > ();

  //which ticks are visible on the screen
  float visibleTickRadius = 0.5 * width * TPP;

  //draws all of the notes that are currently visible on the screen
  for (int i = 0; i < notes.size(); i++) {

    Note cur = notes.get(i);
    if (cur.startTick <= currentTick + visibleTickRadius && cur.endTick >= currentTick - visibleTickRadius) {

      //selects the color of the notes
      if (circleOfFifthsMode) {
        fill((((cur.pitch) * 7) % 12) * 30, 360, 360, 210);
      } else {
        fill((((cur.pitch)) % 12) * 30, 360, 360, 210);
      }

      //if the note is currently playing, outline it
      if ((currentTick >= cur.startTick) && (currentTick <= cur.endTick)) {
        stroke(255);
        /* curNotes.add(notesLookup[(cur.pitch)%12]); */
      } else {
        noStroke();
      }
      //draw the note itself
      rect((float)(offset + (double) cur.startTick / TPP + width / 2), map(cur.pitch, minPitch - 2, maxPitch + 2, height, 0), (float) cur.length / TPP, 2 * height / (maxPitch - minPitch));
    } else if (cur.startTick > currentTick + visibleTickRadius) {
      //if the note is not visible at the moment, do not draw it
      break;
    }

  }

  //if there are no longer any notes visible on the screen, render the video
  if (currentTick > lastTick + visibleTickRadius) {
    println("rendering...");
    videoExport.setAudioFileName(audioOutputPath);
    videoExport.saveFrame();
    exit();
  }

  //increment the current tick
  currentTick = frameCount * ticksPerFrame;

  //save the frame to the video export
  videoExport.saveFrame();

}

//if the spacebar is pressed, immediately stop and render the video
//useful for testing purposes
void keyPressed() {

  if (key == ' ') {

    videoExport.saveFrame();
    exit();

  }

}
