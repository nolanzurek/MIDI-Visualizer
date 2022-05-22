public class Note {
   byte channel;
   byte pitch;
   byte velocity;
   long startTick;
   long endTick;
   long length;
   int track;
   public Note(byte channel, byte pitch, byte velocity, long startTick, long endTick, int track) {
      this.channel = channel;
      this.pitch = pitch;
      this.velocity = velocity;
      this.startTick = startTick;
      this.endTick = endTick;
      length = endTick - startTick;
      this.track = track;
   }
}
