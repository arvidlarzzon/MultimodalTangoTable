/**
  * This sketch demonstrates how to use an FFT to analyze
  * the audio being generated by an AudioPlayer.
  * <p>
  * FFT stands for Fast Fourier Transform, which is a 
  * method of analyzing audio that allows you to visualize 
  * the frequency content of a signal. You've seen 
  * visualizations like this before in music players 
  * and car stereos.
  * <p>
  * For more information about Minim and additional features, 
  * visit http://code.compartmental.net/minim/
  */

import ddf.minim.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;
import ddf.minim.analysis.*;

class Player {
  Minim       minim;
  AudioOutput out;
  FFT         fft;
  
  final int maxSpecSize = 8;
  
  JSONObject song;
  JSONObject filter;
  JSONObject echo;
  JSONObject flange;
  
  JSONArray  waveform;
  JSONObject songFiducial;
  JSONObject filterFiducial;
  JSONObject echoFiducial;
  JSONObject flangeFiducial;
  
  TickRate rateControl;
  final float minTickRate = 0.0;
  final float maxTickRate = 1.5;
  final float deltaTickrate = 0.025;
  final float defaultTickRate = 1.0;
  
  Gain gainControl;
  final float minGain = -60.0;
  final float maxGain = 0.0;
  final float deltaGain = 1.0;
  final float defaultGain = 0.0;
  
  Delay delayControl;
  final float delayAmp = 0.4;
  final float minDelayTime = 0.05;
  final float maxDelayTime = 0.4;
  final float deltaDelayTime = 0.01;
  final float defaultDelayTime = minDelayTime;
  
  Flanger flangeControl;
  final float defaultFlangeRate = 1.0; // in Hz, max value 3 and min 0.1
  final float maxFlangeRate = 3.0;
  final float minFlangeRate = 0.1;
  final float stepFlangeRate = 0.1;
  final float defaultFlangeDepth = 1.0;
  final float maxFlangeDepth = 5.0;
  final float minFlangeDepth = 0.0;
  final float stepFlangeDepth = 0.2;
  
  MoogFilter  filterControl;
  final float filterResonance = 0.5;
  final MoogFilter.Type filterType = MoogFilter.Type.LP;
  final float minFilterFrequency = 200;
  final float maxFilterFrequency = 12000;
  final float deltaFilterFrequency = 500;
  final float defaultFilterFrequency = (maxFilterFrequency - minFilterFrequency)/2;
  
  Bypass<Delay> delayBypassControl;
  Bypass<MoogFilter> filterBypassControl;
  Bypass<Flanger> flangeBypassControl;
  
  FilePlayer filePlayer;
  AudioRecordingStream fileStream;

  Player(MultimodalTangoTable server) {
    minim = new Minim(server);
    out = minim.getLineOut();
    
    fileStream = minim.loadFileStream("Daft Punk - Around The World.mp3");
    filePlayer = new FilePlayer(fileStream);
    
    //Volume
    gainControl = new Gain(defaultGain);
    
    //BPM
    rateControl = new TickRate(defaultTickRate);
    rateControl.setInterpolation(true); //stops the audio from being "scratchy" for slowers paces
    
    //Echo
    delayControl = new Delay(maxDelayTime, delayAmp, true, true);
    delayControl.setDelTime(minDelayTime);
    
    //Flanger
    flangeControl = new Flanger( 1,     // delay length in milliseconds ( clamped to [0,100] )
                        defaultFlangeRate,   // lfo rate in Hz ( clamped at low end to 0.001 )
                        3,     // delay depth in milliseconds ( minimum of 0 )
                        0.5f,   // amount of feedback ( clamped to [0,1] )
                        1f,   // amount of dry signal ( clamped to [0,1] )
                        0.7f    // amount of wet signal ( clamped to [0,1] )
                        );
                      
    //Filter
    filterControl = new MoogFilter(defaultFilterFrequency, filterResonance, filterType);
    
    //Bypasses, allows us to toggle ugens.
    delayBypassControl = new Bypass<Delay>(delayControl);
    filterBypassControl = new Bypass<MoogFilter>(filterControl);
    flangeBypassControl = new Bypass<Flanger>(flangeControl);
    
    filePlayer.patch(filterBypassControl).patch(delayBypassControl).patch(flangeBypassControl).patch(gainControl).patch(rateControl).patch(out);
    fft = new FFT(out.bufferSize() , filePlayer.sampleRate());   
    
    
    //Default values
    song = new JSONObject();
    songFiducial = new JSONObject();
    
    waveform = new JSONArray();
    
    filter = new JSONObject();
    filterFiducial = new JSONObject();
    
    echo = new JSONObject();
    echoFiducial = new JSONObject();
    
    flange = new JSONObject();
    flangeFiducial = new JSONObject();
    
    //Filter info
    filterFiducial.setInt("x", 0);
    filterFiducial.setInt("y", 0);
    
    filter.setBoolean("active", !filterBypassControl.isActive());
    filter.setFloat("frequency_value", defaultFilterFrequency/maxFilterFrequency);
    filter.setJSONObject("fiducial", filterFiducial);
    
    //Echo info
    echoFiducial.setInt("x", 0);
    echoFiducial.setInt("y", 0);
    
    echo.setBoolean("active", !delayBypassControl.isActive());
    echo.setFloat("delay_value", defaultDelayTime/maxDelayTime);
    echo.setJSONObject("fiducial", echoFiducial);
    
    //Flange info
    flangeFiducial.setInt("x", 0);
    flangeFiducial.setInt("y", 0);
    
    flange.setBoolean("active", !flangeBypassControl.isActive());
    flange.setFloat("rate_value", defaultFlangeRate/maxFlangeRate);
    flange.setFloat("depth_value", defaultFlangeDepth/maxFlangeDepth);    
    flange.setJSONObject("fiducial", flangeFiducial);
    
    //Song info
    songFiducial.setInt("x", 0);
    songFiducial.setInt("y", 0);
    
    song.setInt("id", 1);
    song.setFloat("tempo", defaultTickRate);
    song.setFloat("position", filePlayer.position()/filePlayer.length());
    song.setFloat("volume", 1 + (defaultGain/minGain));
    song.setBoolean("playing", filePlayer.isPlaying());
    song.setJSONArray("waveform", waveform);
    song.setJSONObject("echo", echo);
    song.setJSONObject("flange", flange);
    song.setJSONObject("filter", filter);
    song.setJSONObject("fiducial", songFiducial);
    
    // Sets start value to false
    toggleFilter(); 
    toggleFlanger();
    toggleEcho();
  }
  
  
  
  //Toggle/Play/Pause
  Boolean isPlaying() {
    return filePlayer.isPlaying();
  }
  
  void play() {
    filePlayer.loop();
    song.setBoolean("playing", true);
  }
  
  void pause() {
    filePlayer.pause();
    song.setBoolean("playing", false);
  }
  
  void togglePlay() {
    if (filePlayer.isPlaying()) {
      pause();
    } else {
      play();
    }
  }
  
  
  
  //Volume
  void resetVolume() {
    gainControl.gain.setLastValue(defaultGain);
    gainControl.setValue(defaultGain);
    song.setFloat("volume", 1 - (defaultGain/minGain));
  }
  void setVolume(float yValue){ // value of fiducial y-axis
    if (yValue < 0){
      yValue = 0;
    }
    if (yValue > 1){
      yValue = 1;
    }
    float newVal = (maxGain - minGain) * yValue + minGain;
    gainControl.gain.setLastValue(newVal);
    gainControl.setValue(newVal);
    song.setFloat("volume", 1 - newVal/minGain);
  }
   
  //Bpm
  void resetBpm() {
    rateControl.value.setLastValue(defaultTickRate);
    song.setFloat("tempo", defaultTickRate);
  }
  
  
  void increaseBpm() {
    float newTickRate = min(rateControl.value.getLastValue() + deltaTickrate, maxTickRate);
    rateControl.value.setLastValue(newTickRate);
    song.setFloat("tempo", newTickRate);
  }
  
  void decreaseBpm() {
    float newTickRate = max(rateControl.value.getLastValue() - deltaTickrate, minTickRate);
    rateControl.value.setLastValue(newTickRate);
    song.setFloat("tempo", newTickRate);
  }
  
  
  
  //Echo
  void toggleEcho() {
    if ( delayBypassControl.isActive() ) {
      delayBypassControl.deactivate();
      // delayControl.setDelTime(defaultDelayTime); //Comment out this line if we don't want to reset delay when toggling.
    } else {
      delayBypassControl.activate();
    }
    
    echo.setBoolean("active", !delayBypassControl.isActive());
  }
  
  void increaseEcho() {
    float newDelayTime = min(delayControl.delTime.getLastValue() + deltaDelayTime, maxDelayTime);
    delayControl.setDelTime(newDelayTime);
    echo.setFloat("delay_value", newDelayTime);
  }
  
  void decreaseEcho() {
    float newDelayTime = max(delayControl.delTime.getLastValue() - deltaDelayTime, minDelayTime);
    delayControl.setDelTime(newDelayTime);
    echo.setFloat("delay_value", newDelayTime);
  }
  
  //Flanger
  void toggleFlanger() {
    if ( flangeBypassControl.isActive() ) {
      flangeBypassControl.deactivate();
    } else {
      flangeBypassControl.activate();
    }
    flange.setBoolean("active", !flangeBypassControl.isActive());
  }
  void setFlangeDepth(float yValue){ // value of fiducial y-axis
    if (yValue < 0){
      yValue = 0;
    }
    if (yValue > 1){
      yValue = 1;
    }
    float newVal = (maxFlangeDepth - minFlangeDepth) * yValue + minFlangeDepth;
    flangeControl.depth.setLastValue(newVal);
    flange.setFloat("depth_value", newVal);
  }
  void increaseFlangeRate() { // Angle adjusted
    float newFlangeRate = min(flangeControl.rate.getLastValue() + stepFlangeRate, maxFlangeRate);
    flangeControl.rate.setLastValue(newFlangeRate);
    flange.setFloat("rate_value", newFlangeRate);
  }
  
  void decreaseFlangeRate() { // Angle
    float newFlangeRate = max(flangeControl.rate.getLastValue() - stepFlangeRate, minFlangeRate);
    flangeControl.rate.setLastValue(newFlangeRate);
    flange.setFloat("rate_value", newFlangeRate);
  }
  
  //Filter
  void toggleFilter() {
    if ( filterBypassControl.isActive() ) {
      filterBypassControl.deactivate();
      // filterControl.frequency.setLastValue(defaultFilterFrequency); //Comment out this line if we don't want to reset filter when toggling.
    } else {
      filterBypassControl.activate();
    }
    
    filter.setBoolean("active", !filterBypassControl.isActive());
  }
  
  void setFilter(float xValue){ // value of fiducial x-axis
    if (xValue < 0){
      xValue = 0;
    }
    if (xValue > 1){
      xValue = 1;
    }
    float newVal = (maxFilterFrequency - minFilterFrequency) * xValue + minFilterFrequency;
    filterControl.frequency.setLastValue(newVal);
    filter.setFloat("frequency_value", newVal);
  }
  
  //To string
  String toJsonString() {
    //Song info
    fft.forward( out.mix );
    
    for(int i = 0; i < min(fft.specSize(), maxSpecSize); i++) {
      waveform.setFloat(i, fft.getBand(i));
      // draw the line for frequency band i, scaling it up a bit so we can see it
      // rect(i * 10, 0, 5, fft.getBand(i)*3);
    }
     
    song.setFloat("position", ((float) filePlayer.position()/filePlayer.length()));
    
    return song.toString();
  }
}