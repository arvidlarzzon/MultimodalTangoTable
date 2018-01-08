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
  
  final int maxSpecSize = 60;
  
  int songIndex = -1;
  boolean songActive = false;
  boolean filePlayerLoaded = false;
  String currentEffect = "";
  
  JSONObject song;
  JSONObject bpm;
  JSONObject filter;
  JSONObject echo;
  JSONObject flange;
  
  JSONArray  waveform;
  JSONObject songFiducial;
  JSONObject bpmFiducial;
  JSONObject filterFiducial;
  JSONObject echoFiducial;
  JSONObject flangeFiducial;
  
  TickRate rateControl;
  boolean rateControlActive = false;
  final float minTickRate = 0.0;
  final float maxTickRate = 2.0;
  final float deltaTickrate = 0.025;
  final float defaultTickRate = 1.0;
  
  Gain gainControl;
  final float minGain = -60.0;
  final float maxGain = 0.0;
  final float deltaGain = 1.0;
  final float defaultGain = -6.0;
  
  
  boolean delayActive = false;
  Delay delayControl;
  final float delayAmp = 0.4;
  final float minDelayTime = 0.05;
  final float maxDelayTime = 0.4;
  final float deltaDelayTime = 0.01;
  final float defaultDelayTime = minDelayTime;
  
  
  boolean flangeActive = false;
  Flanger flangeControl;
  final float defaultFlangeRate = 1.0; // in Hz, max value 3 and min 0.1
  final float maxFlangeRate = 3.0;
  final float minFlangeRate = 0.1;
  final float stepFlangeRate = 0.1;
  final float defaultFlangeDepth = 1.0;
  final float maxFlangeDepth = 5.0;
  final float minFlangeDepth = 0.0;
  final float stepFlangeDepth = 0.2;
  
  boolean filterActive = false;
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
    
    
    //Default values
    song = new JSONObject();
    songFiducial = new JSONObject();
    
    waveform = new JSONArray();
    
    bpm = new JSONObject();
    bpmFiducial = new JSONObject();
    
    filter = new JSONObject();
    filterFiducial = new JSONObject();
    
    echo = new JSONObject();
    echoFiducial = new JSONObject();
    
    flange = new JSONObject();
    flangeFiducial = new JSONObject();
    
    //BPM info
    bpmFiducial.setFloat("x", 0.0);
    bpmFiducial.setFloat("y", 0.0);
    bpm.setBoolean("active", rateControlActive);
    bpm.setJSONObject("fiducial", bpmFiducial);
    
    //Filter info
    filterFiducial.setFloat("x", 0.0);
    filterFiducial.setFloat("y", 0.0);
    filter.setBoolean("active", filterActive);
    filter.setJSONObject("fiducial", filterFiducial);
    
    //Echo info
    echoFiducial.setFloat("x", 0.0);
    echoFiducial.setFloat("y", 0.0);
    echo.setBoolean("active", delayActive);
    echo.setJSONObject("fiducial", echoFiducial);
    
    //Flange info
    flangeFiducial.setFloat("x", 0.0);
    flangeFiducial.setFloat("y", 0.0);
    flange.setBoolean("active", flangeActive);
    flange.setJSONObject("fiducial", flangeFiducial);
    
    //Song info
    songFiducial.setFloat("x", 0.0);
    songFiducial.setFloat("y", 0.0);
    
    song.setInt("id", songIndex);
    song.setBoolean("playing", songActive);
    song.setString("current_effect", currentEffect);
    song.setJSONArray("waveform", waveform);
    song.setJSONObject("bpm", bpm);
    song.setJSONObject("echo", echo);
    song.setJSONObject("flange", flange);
    song.setJSONObject("filter", filter);
    song.setJSONObject("fiducial", songFiducial);
  }
  
  void loadInitialSong(int index) {
    //Load song
    fileStream = minim.loadFileStream(getSongNameByIndex(index));
    filePlayer = new FilePlayer(fileStream);
    
    
    
    //Initialize uGens with default values
    gainControl = new Gain(defaultGain); //Volume
    
    //BPM
    rateControl = new TickRate(defaultTickRate);
    rateControl.setInterpolation(true); //stops the audio from being "scratchy" for slowers paces
    
    //Echo
    delayControl = new Delay(maxDelayTime, delayAmp, true, true);
    delayControl.setDelTime(minDelayTime);
    
    //Flanger
    flangeControl = new Flanger(1, defaultFlangeRate, defaultFlangeDepth, 0.5f, 1f, 0.7f);
                      
    //Filter
    filterControl = new MoogFilter(defaultFilterFrequency, filterResonance, filterType);
    
    //Bypasses, allows us to toggle ugens.
    delayBypassControl = new Bypass<Delay>(delayControl);
    filterBypassControl = new Bypass<MoogFilter>(filterControl);
    flangeBypassControl = new Bypass<Flanger>(flangeControl);
    
    
    
    //Apply patches and initialize fft
    filePlayer.patch(filterBypassControl).patch(delayBypassControl).patch(flangeBypassControl).patch(gainControl).patch(rateControl).patch(out);
    fft = new FFT(out.bufferSize() , filePlayer.sampleRate());
    
    
    
    //Set relevant json attributes
    bpm.setFloat("tempo", map(defaultTickRate, minTickRate, maxTickRate, 0, 1)); //BPM info
    filter.setFloat("frequency_value", map(defaultFilterFrequency, minFilterFrequency, maxFilterFrequency, 1, 0)); //Filter info
    echo.setFloat("delay_value", map(defaultDelayTime, minDelayTime, maxDelayTime, 0, 1)); //Echo info
    
    //Flange info 
    flange.setFloat("rate_value", map(defaultFlangeRate, minFlangeRate, maxFlangeRate, 0, 1));
    flange.setFloat("depth_value", map(defaultFlangeDepth, minFlangeDepth, maxFlangeDepth, 0, 1));
    
    //Song info
    songIndex = index;
    song.setInt("id", index);
    song.setInt("length", filePlayer.length());
    song.setFloat("position", filePlayer.position()/filePlayer.length());
    song.setFloat("volume", 1 - (defaultGain/minGain));
    
    
    
    //The effects are on by default, turn them off
    filterBypassControl.activate();
    delayBypassControl.activate();
    flangeBypassControl.activate();
    
    
    filePlayerLoaded = true;
  }
  
  void loadNewSong(int index) {
    //Get recent values, will be used to initialize ugens.
    float currentGain = gainControl.gain.getLastValue();
    float currentTickRate = rateControl.value.getLastValue();
    float currentDelayTime = delayControl.delTime.getLastValue();
    float currentFlangeRate = flangeControl.rate.getLastValue();
    float currentFlangeDepth = flangeControl.depth.getLastValue();
    float currentFilterFrequency = filterControl.frequency.getLastValue();
    
    
    
    //Pause and close current file player
    filePlayer.pause();
    filePlayer.close();
    
    
    
    //Load song
    fileStream = minim.loadFileStream(getSongNameByIndex(index));
    filePlayer = new FilePlayer(fileStream);
    
    
    
    //Initialize uGens
    gainControl = new Gain(currentGain); //Volume
    
    //BPM
    rateControl = new TickRate(currentTickRate);
    rateControl.setInterpolation(true); //stops the audio from being "scratchy" for slowers paces
    
    //Echo
    delayControl = new Delay(maxDelayTime, delayAmp, true, true);
    delayControl.setDelTime(currentDelayTime);
    
    //Flanger
    flangeControl = new Flanger(1, currentFlangeRate, currentFlangeDepth, 0.5f, 1f, 0.7f);
                      
    //Filter
    filterControl = new MoogFilter(currentFilterFrequency, filterResonance, filterType);
    
    //Bypasses, allows us to toggle ugens.
    delayBypassControl = new Bypass<Delay>(delayControl);
    filterBypassControl = new Bypass<MoogFilter>(filterControl);
    flangeBypassControl = new Bypass<Flanger>(flangeControl);
    
    
    
    //Apply patches and initialize fft
    filePlayer.patch(filterBypassControl).patch(delayBypassControl).patch(flangeBypassControl).patch(gainControl).patch(rateControl).patch(out);
    fft = new FFT(out.bufferSize() , filePlayer.sampleRate());
    
    
    
    //Set relevant json attributes
    bpm.setFloat("tempo", map(currentTickRate, minTickRate, maxTickRate, 0, 1)); //BPM info
    filter.setFloat("frequency_value", map(currentFilterFrequency, minFilterFrequency, maxFilterFrequency, 1, 0)); //Filter info
    echo.setFloat("delay_value", map(currentDelayTime, minDelayTime, maxDelayTime, 0, 1)); //Echo info
    
    //Flange info 
    flange.setFloat("rate_value", map(currentFlangeRate, minFlangeRate, maxFlangeRate, 0, 1));
    flange.setFloat("depth_value", map(currentFlangeDepth, minFlangeDepth, maxFlangeDepth, 0, 1));
    
    //Song info
    songIndex = index;
    song.setInt("id", index);
    song.setInt("length", filePlayer.length());
    song.setFloat("position", filePlayer.position()/filePlayer.length());
    song.setFloat("volume", 1 - (currentGain/minGain));
    
    
    
    //Toggle shit depending on if they were previously active
    if(songActive) {
      play();
    }
    
    if(!filterActive) {
      filterBypassControl.activate();
    }
    
    if(!delayActive) {
      delayBypassControl.activate();
    }
    
    if(!flangeActive) {
      flangeBypassControl.activate();
    }
  }
  
  String getSongNameByIndex(int index) {
    switch(index) {
      case 0:
        return "0.mp3";
      
      case 1:
        return "1.mp3";
      
      case 2:
        return "2.mp3";
      
      case 3:
        return "3.mp3";
      
      case 4:
        return "4.mp3";
      
      case 5:
        return "5.mp3";
        
      default:
        return "0.mp3";
    }
  }
  
  
  void setSong(int id) {
    if(filePlayerLoaded) {
      if(songIndex != id) {
        loadNewSong(id);
      }
    } else {
      loadInitialSong(id);
    }
  }
  
  void setEffect(String effect) {
    currentEffect = effect;
    song.setString("current_effect", currentEffect);
  }
  
  //Toggle/Play/Pause
  Boolean isPlaying() {
    return filePlayer.isPlaying();
  }
  
  void play() {
    songActive = true;
    song.setBoolean("playing", true);
    filePlayer.loop();
  }
  
  void pause() {
    songActive = false;
    song.setBoolean("playing", false);
    filePlayer.pause();
  }
  
  void togglePlay() {
    if( filePlayerLoaded ) {
      if (songActive) {
        pause();
      } else {
        play();
      }
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
  
  void increaseVolume() {
    float newGain = min(gainControl.gain.getLastValue() + deltaGain, maxGain);
    gainControl.gain.setLastValue(newGain);
    gainControl.setValue(newGain);
    song.setFloat("volume", 1 - (newGain/minGain));
  }
  
  void decreaseVolume() {
    float newGain = max(gainControl.gain.getLastValue() - deltaGain, minGain);
    gainControl.gain.setLastValue(newGain);
    gainControl.setValue(newGain);
    song.setFloat("volume", 1 - (newGain/minGain));
  }
   
   
  //Bpm
  void resetBpm() {
    rateControl.value.setLastValue(defaultTickRate);
    bpm.setFloat("tempo", map(defaultTickRate, minTickRate, maxTickRate, 0, 1));
  }
  
  void toggleBpm() {
    if(rateControlActive) {
      if(currentEffect == "bpm") {
        rateControl.value.setLastValue(defaultTickRate);
        bpm.setFloat("tempo", map(defaultTickRate, minTickRate, maxTickRate, 0, 1));
        
        setEffect("");
        rateControlActive = false;
        bpm.setBoolean("active", rateControlActive);
      } else {
        setEffect("bpm");
      }
    } else {
        setEffect("bpm");
        rateControlActive = true;
        bpm.setBoolean("active", rateControlActive);
    }
  }
  
  void increaseBpm() {
    float newTickRate = min(rateControl.value.getLastValue() + deltaTickrate, maxTickRate);
    rateControl.value.setLastValue(newTickRate);
    bpm.setFloat("tempo", map(newTickRate, minTickRate, maxTickRate, 0, 1));
  }
  
  void decreaseBpm() {
    float newTickRate = max(rateControl.value.getLastValue() - deltaTickrate, minTickRate);
    rateControl.value.setLastValue(newTickRate);
    bpm.setFloat("tempo", map(newTickRate, minTickRate, maxTickRate, 0, 1));
  }
  
  
  
  //Echo
  void toggleEcho() {
    if(delayActive) {
      if(currentEffect == "echo") {
        delayBypassControl.activate();
        
        setEffect("");
        delayActive = false;
        echo.setBoolean("active", false);
      } else {
        setEffect("echo");
      }
    } else {
      delayBypassControl.deactivate();
        
      setEffect("echo");
      delayActive = true;
      echo.setBoolean("active", true);
    }
  }
  
  void increaseEcho() {
    float newDelayTime = min(delayControl.delTime.getLastValue() + deltaDelayTime, maxDelayTime);
    delayControl.setDelTime(newDelayTime);
    echo.setFloat("delay_value", map(newDelayTime, minDelayTime, maxDelayTime, 0, 1));
  }
  
  void decreaseEcho() {
    float newDelayTime = max(delayControl.delTime.getLastValue() - deltaDelayTime, minDelayTime);
    delayControl.setDelTime(newDelayTime);
    echo.setFloat("delay_value", map(newDelayTime, minDelayTime, maxDelayTime, 0, 1));
  }
  
  
  
  //Flanger
  void toggleFlanger() {
    if(flangeActive) {
      if(currentEffect == "flanger") {
        flangeBypassControl.activate();
        
        setEffect("");
        flangeActive = false;
        flange.setBoolean("active", false);
      } else {
        setEffect("flanger");
      }
    } else {
      flangeBypassControl.deactivate();
        
      setEffect("flanger");
      flangeActive = true;
      flange.setBoolean("active", true);
    }
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
    flange.setFloat("depth_value", map(newVal, minFlangeDepth, maxFlangeDepth, 0, 1));
  }

  void increaseFlangeRate() { 
    float newFlangeRate = min(flangeControl.rate.getLastValue() + stepFlangeRate, maxFlangeRate);
    flangeControl.rate.setLastValue(newFlangeRate);
    flange.setFloat("rate_value", map(newFlangeRate, minFlangeRate, maxFlangeRate, 0, 1));
  }
  
  void decreaseFlangeRate() { 
    float newFlangeRate = max(flangeControl.rate.getLastValue() - stepFlangeRate, minFlangeRate);
    flangeControl.rate.setLastValue(newFlangeRate);
    flange.setFloat("rate_value", map(newFlangeRate, minFlangeRate, maxFlangeRate, 0, 1));
  }
  
  void increaseFlangeDepth() {
    float newFlangeDepth = min(flangeControl.depth.getLastValue() + stepFlangeDepth, maxFlangeDepth);
    flangeControl.depth.setLastValue(newFlangeDepth);
    flange.setFloat("depth_value", map(newFlangeDepth, minFlangeDepth, maxFlangeDepth, 0, 1));
  }
  
  void decreaseFlangeDepth() {
    float newFlangeDepth = max(flangeControl.depth.getLastValue() - stepFlangeDepth, minFlangeDepth);
    flangeControl.depth.setLastValue(newFlangeDepth);
    flange.setFloat("depth_value", map(newFlangeDepth, minFlangeDepth, maxFlangeDepth, 0, 1));
  }
  
  //Filter
  void toggleFilter() {
    if(filterActive) {
      if(currentEffect == "filter") {
        filterBypassControl.activate();
        
        setEffect("");
        filterActive = false;
        filter.setBoolean("active", false);
      } else {
        setEffect("filter");
      }
    } else {
      filterBypassControl.deactivate();
        
      setEffect("filter");
      filterActive = true;
      filter.setBoolean("active", true);
    }
  }
  
  void setFilter(float xValue){
    if (xValue < 0){
      xValue = 0;
    }
    if (xValue > 1){
      xValue = 1;
    }
    float newVal = (maxFilterFrequency - minFilterFrequency) * xValue + minFilterFrequency;
    filterControl.frequency.setLastValue(newVal);
    filter.setFloat("frequency_value", map(newVal, minFilterFrequency, maxFilterFrequency, 1, 0));
  }
  
  void increaseFilter() {
    float newFreq = min(filterControl.frequency.getLastValue() + deltaFilterFrequency, maxFilterFrequency);
    filterControl.frequency.setLastValue(newFreq);
    filter.setFloat("frequency_value", map(newFreq, minFilterFrequency, maxFilterFrequency, 1, 0));
  }
  
  void decreaseFilter() {
    float newFreq = max(filterControl.frequency.getLastValue() - deltaFilterFrequency, minFilterFrequency);
    filterControl.frequency.setLastValue(newFreq);
    filter.setFloat("frequency_value", map(newFreq, minFilterFrequency, maxFilterFrequency, 1, 0));
  }
  
  //To string
  String toJsonString() {
    if(filePlayerLoaded) {
      fft.forward( out.mix );
    
      for(int i = 0; i < min(fft.specSize(), maxSpecSize); i++) {
        waveform.setFloat(i, fft.getBand(i));
      }
     
      song.setFloat("position", ((float) filePlayer.position()/filePlayer.length()));
    }
    
    return song.toString();
  }
}