/**
* Instances of this class calculate all the variables needed to display each 
* earthquake and its associated waves based on its initial magnitude, longitude 
* and latitude.
*
* Newly added earthquakes are displayed in red before switching to gold (and vice
* versa in Poseidon mode). Two waves originate from each earthquake, and behave 
* differently depending on whether they are on land or in water, before eventually
* fading out.
*/

class SingleEvent {  
  // declare local variables
  float epiX; // X coordinate for epicentre
  float epiY; // Y coordinate for epicentre
  float epiDiameter; // diameter of epicentre
  float w1X; // X coordinate for wave 1
  float w1Y; // Y coordinate for wave 1
  float w2X; // X coordinate for wave 2 
  float w2Y; // Y coordinate for wave 2
  float wWidth; // wave width
  float wDecay = .001; // decay of wave width
  boolean lastEarthquake; // true for last displayed earthquake

  // overloaded constructor
  SingleEvent(float magnitude, float longitude, float latitude) {

    // initialise wave width (thicker wave for larger magnitude)
    wWidth = map(magnitude, -1, 10, .7, 1) * exp(widthModifier);

    // initialise epicentre diameter using rough approximation of Richter scale
    epiDiameter = exp(map(magnitude, -1, 10, 0, 4));

    // initialise epicentre coordinates depending on longitude and latitude
    epiX = map(longitude, -170, 190, 0, width);
    epiY = map(latitude, -55, 83, height, 0);

    // initialise wave coordinates
    w1X = epiX;
    w1Y = epiY;
    w2X = epiX;    
    w2Y = epiY;

    // indicate instance as last added earthquake
    lastEarthquake = true;
  }

  void display() {
    // constrain wave coordinates so they exactly match 2D array values for pixel colour
    int cW1X = (int)constrain(w1X, 0, width-1);
    int cW1Y = (int)constrain(w1Y, 0, height-1);
    int cW2X = (int)constrain(w2X, 0, width-1);
    int cW2Y = (int)constrain(w2Y, 0, height-1);

    // check if waves are currently on land or in water
    color w1Background = mapColour[cW1X][cW1Y];
    color w2Background = mapColour[cW2X][cW2Y];

    // declare local variables for wave status
    int w1Status; // 0: out of screen, 1: on land, 2: in water
    int w2Status; // 0: out of screen, 1: on land, 2: in water

    // check status of wave 1
    if (w1X <=0 || w1X >= width-1)
      w1Status = 0; // out of screen    
    else if (w1Background == #000000) 
      w1Status = 1; // on land
    else
      w1Status = 2; // in water

    // check status of wave 2
    if (w2X <=0 || w2X >= width-1)
      w2Status = 0; // out of screen    
    else if (w2Background == #000000) 
      w2Status = 1; // on land
    else
      w2Status = 2; // in water

    // draw epicentre
    if (lastEarthquake)
      fill (epicentreColour1); // in red if last in date
    else
      fill(epicentreColour2); // in gold otherwise (vice versa for Poseidon mode)     
    stroke(backgroundColour);
    strokeWeight(.1);
    ellipse(epiX, epiY, epiDiameter, epiDiameter);
    noStroke();

    // draw wave 1
    if (w1Status == 0)
      noFill(); // don't draw if out of screen
    else
      fill(waveColour);
    ellipse(w1X, w1Y, wWidth, wWidth);

    // draw wave 2
    if (w2Status == 0)
      noFill(); // don't draw if out of screen
    else
      fill(waveColour);      
    ellipse(w2X, w2Y, wWidth, wWidth);

    // reduce wave width for next loop
    wWidth -= wDecay;
    if (wWidth <= wDecay)
      wWidth = 0; // and make it disappear if it gets too small

    // adjust both waves' X coordinates for next loop
    w1X--; // move wave 1 to the left
    w2X++; // move wave 2 to the right

    // adjust wave 1's Y coordinate for next loop
    if (w1Status == 1) // if on land, move randomly 
      w1Y += random(-landRandom * waveModifier, landRandom * waveModifier);  
    if (w1Status == 2) // if on water, move smoothly
      w1Y += noise(w1X * waterNoise * waveModifier, w1Y * waterNoise * waveModifier) 
        - waterOffset; 

    // adjust wave 2's Y coordinate for next loop
    if (w2Status == 1) // if on land, move randomly
      w2Y += random(-landRandom * waveModifier, landRandom * waveModifier); 
    if (w2Status == 2) // if on water, move smoothly
      w2Y += noise(w2X * waterNoise * waveModifier, w2Y * waterNoise * waveModifier) 
        - waterOffset; 

    // update epicentre colour
    lastEarthquake = false;
  }
}