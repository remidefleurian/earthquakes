/**
 * This sketch uses archive and real-time data from the US Geological Survey
 * to display past and current earthquakes on a black canvas. The canvas is superposed
 * to a black-and-white map of the world, the pixel values of which are stored in
 * a 2D array.
 *
 * When an earthquake is added to the visualisation, two waves originate from its
 * epicentre and head towards the left and right edges of the screen. If the waves
 * are on what should be a continent, they behave randomly. If they are on what should
 * be water, they behave more smoothly, following a Perlin noise pattern. As more
 * and more waves are displayed, the shapes of the continents slowly become apparent.
 *
 * Users can choose between four modes:
 * 1. Real time: shows all magnitudes for the past hour, updated every 5 minutes
 * 2. Past month: shows magnitudes above 2.5 over the past month
 * 3. Free choice: shows magnitudes above 2.5 over a user-defined time period
 * 4. Poseidon: users can create their own earthquakes
 * 
 * A hidden mode, accessed when pressing 'B', loads pre-saved data, in case the 
 * online database becomes momentarily unavailable.
 *
 * Online data taken from:
 * http://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php
 * http://earthquake.usgs.gov/earthquakes/search/
 *
 * Map adapted from an equirectangular projection downloaded from:
 * https://pixelmap.amcharts.com/
 *
 * Instructions to calculate time difference between two dates taken from:
 * http://www.faqs.org/qa/qa-10170.html
 *
 * Use of ArrayList to display multiple instances of a class inspired from:
 * https://www.openprocessing.org/sketch/8676#
 */

// background image
PImage map; // black and white map of the world
color[][] mapColour; // colour for each pixel of the map

// colours
color backgroundColour; // white or black depending on state
color waveColour; // white or black depending on state
color epicentreColour1; // gold or red depending on state
color epicentreColour2; // gold or red depending on state

// font
PFont avenir;

// online data
JSONObject data;
JSONArray eventList;

// object
ArrayList earthquakes;

// URLs
String realTimeURL = "http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson";
String pastMonthURL = "http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_month.geojson";
String freeChoiceFrontURL = "https://earthquake.usgs.gov/fdsnws/event/1/query.geojson?starttime=";
String freeChoiceMidURL = "%2000:00:00&endtime=";
String freeChoiceEndURL = "%2023:59:59&minmagnitude=2.5&orderby=time";

// playback speed
long speed; // 1 for real time, 600000 for past month, faster if higher

// wave patterns
float landRandom = 1.5; // more random if higher
float waterNoise = .02; // more random if higher
float waterOffset = .4; // adjust this to make the waves go in a straight line

// random, noise, and wave width modifiers for Poseidon mode
float widthModifier; // modifies wave width by factor of exp(-1.5) to exp(1.5)
float waveModifier; // modifies random and noise values by factor of 0 to 2

// trackers
int state; // 1: real time, 2: pastmonth, 3: freechoice, 4: Poseidon, 5: backup
boolean changingState; // true when initialising state
boolean readingData; // true when data is read in states 1, 2, 3 and 5
boolean settingDate; // true when changing date before switching to state 3
boolean errorMessage; // true when displaying error message
int dateBeingChanged; // track which day/month/year is being adjusted in state 3
int eventIndex; // array number when reading events from online data
long currentTime; // timer to track millis()
long timeSinceUpdate; // timer to update real time data every 5 minutes in state 1
long previousOnset; // timer to track event onsets when reading data
long clickOnset; // timer to track mouse button pressed in state 4

// dates for state 3
int day[] = {1, 31}; // index 0: date from, index 1: date to
int month[] = {1, 1};
int year[] = {2019, 2019};

// library to calculate difference between dates in state 3
import java.util.Date;
import java.util.Calendar;
import java.util.GregorianCalendar;

void setup() {
  fullScreen();

  // load and display map, and store colour of each pixel in 2D array
  map = loadImage("map.png");
  image(map, 0, 0, width, height);
  mapColour = new color[width][height];
  for (int i = 0; i < width; i++) {
    for (int j = 0; j < height; j++) {
      mapColour[i][j] = get(i, j);
    }
  }  

  // reinitialise background
  background(backgroundColour); 

  // create and initialise font
  avenir = createFont("Avenir", 16);
  textFont(avenir);

  // initialise state
  state = 1; // real time
  changingState = true;
}

void draw() {
  changeState(); // reinitialise the state of the sketch
  readEvents(); // add events until the whole list is parsed
  displayEvents(); // display all earthquakes
  userInterface(); // draw UI
}

void changeState() {
  // reinitialise variables if state is changing
  if (changingState) {

    // some variables are reset differently for states 1, 2, 3, and 5
    if (state == 1 || state == 2 || state == 3 || state == 5) {

      // real time
      if (state == 1) {
        speed = 1;     
        data = loadJSONObject(realTimeURL);
        timeSinceUpdate = millis();
      }

      // past month  
      else if (state == 2) {
        speed = 600000; // 10 minutes per millisecond        
        data = loadJSONObject(pastMonthURL);
      }

      // free choice
      else if (state == 3) { 

        // build date strings with "0" in front of day or month if needed
        String date[] = new String[2];
        for (int i = 0; i <= 1; i++) {
          if (day[i] >= 10 && month[i] >= 10) 
            date[i] = str(year[i]) + "-" + str(month[i]) + "-" + str(day[i]);
          else if (day[i] >= 10 && month[i] < 10) 
            date[i] = str(year[i]) + "-0" + str(month[i]) + "-" + str(day[i]);
          else if (day[i] < 10 && month[i] >= 10) 
            date[i] = str(year[i]) + "-" + str(month[i]) + "-0" + str(day[i]);
          else if (day[i] < 10 && month[i] < 10) 
            date[i] = str(year[i]) + "-0" + str(month[i]) + "-0" + str(day[i]);
        }

        // calculate time between date to and date from, in milliseconds
        GregorianCalendar dateFrom = new GregorianCalendar(year[0], month[0], day[0]);
        GregorianCalendar dateTo = new GregorianCalendar(year[1], month[1], day[1]);
        long dateDiff = dateTo.getTime().getTime() - dateFrom.getTime().getTime();

        // set speed relative to the difference between date to and date from
        speed = dateDiff / 5000; 

        // load URL with specified dates
        data = loadJSONObject(freeChoiceFrontURL + date[0] + freeChoiceMidURL
          + date[1] + freeChoiceEndURL);
      }

      // backup (pre-saved JSON file in Processing sketch folder)
      else if (state == 5) {
        speed = 600000; // 10 minutes per millisecond           
        data = loadJSONObject("backup.json");
      }

      // the remaining variables are reset similarly for states 1, 2, 3, and 5
      eventList = data.getJSONArray("features");
      // if there are no events in the data, stop the loop and display error message
      if (eventList.size() == 0) {
        changingState = false;
        readingData = false;
        errorMessage = true;
        return;
      }
      //otherwise, continue resetting other variables
      previousOnset = eventList.getJSONObject(0).getJSONObject("properties")
        .getLong("time");
      earthquakes = new ArrayList<SingleEvent>(); 
      eventIndex = 0;
      widthModifier = 0; 
      waveModifier = 1;
      backgroundColour = 20;
      waveColour = 220;
      epicentreColour1 = #FF6700;
      epicentreColour2 = #FFD40F;
      background(backgroundColour);
      currentTime = 0; 
      settingDate = false;
      readingData = true;
      errorMessage = false;
    }

    // variables are reset in a different way for state 4 (Poseidon)
    if (state == 4) { 
      earthquakes = new ArrayList<SingleEvent>();
      widthModifier = 0;
      waveModifier = 1;
      backgroundColour = 220;
      waveColour = 20;
      epicentreColour1 = #FFD40F;
      epicentreColour2 = #FF6700;
      background(backgroundColour);    
      settingDate = false; 
      readingData = false; 
      errorMessage = false;
    }

    // prevent running this loop until the state changes again
    changingState = false;
  }
}

void readEvents() {
  // if the event list is not fully parsed yet
  if (readingData == true && eventIndex < eventList.size()) { 

    // load event data - the events are read from the bottom of the list up
    JSONObject event = eventList.getJSONObject(eventList.size() - eventIndex - 1);
    JSONObject eventProperties = event.getJSONObject("properties");
    JSONArray eventCoordinates = event.getJSONObject("geometry")
      .getJSONArray("coordinates");

    // store magnitude or assign arbitrary value if it's null
    float magnitude;
    if (eventProperties.isNull("mag") == true) {
      magnitude = 0;
    } else {
      magnitude = eventProperties.getFloat("mag"); // ranges from -1 to 10
    }

    // store coordinates
    float longitude = eventCoordinates.getFloat(0); // ranges from -180 to 180
    float latitude = eventCoordinates.getFloat(1); // ranges from -90 to 90

    // store time and calculate delay between events
    long currentOnset = eventProperties.getLong("time"); // milliseconds in UTC format
    float waitTime = (currentOnset - previousOnset)/speed; // fast speed = short wait

    // if it's time to display a new event
    if (millis() - currentTime >= waitTime) {

      // add a new instance of SingleEvent and update the trackers
      earthquakes.add(new SingleEvent(magnitude, longitude, latitude));
      currentTime = millis();
      previousOnset = currentOnset;
      eventIndex++;
    }

    // if all events have been added, update tracker to bypass this function
  } else {
    readingData = false;
  }

  // if 5 minutes have elapsed in real time mode, update the data and add new events
  if (state == 1 && millis() - timeSinceUpdate >= 300000) {
    data = loadJSONObject(realTimeURL);
    readingData = true;
    timeSinceUpdate = millis();
  }
}

void displayEvents() {
  // display each instance of SingleEvent stored in earthquakes ArrayList
  for (int i = 0; i < earthquakes.size(); i++) {
    SingleEvent earthquake = (SingleEvent) earthquakes.get(i);
    earthquake.display();
  }
}

void userInterface() {  
  // initialise some properties
  strokeWeight(1);
  stroke(waveColour);
  fill(backgroundColour);

  // draw boxes behind text to cover earthquakes, depending on state
  if (state != 4) // text box for all modes except Poseidon mode
    rect(width - 147, 2, 144, 133); 
  if (state == 4) { // boxes for sentence, graph and text in Poseidon mode
    rect(2, 2, 592, 60); 
    rect(width - 296, 2, 293, 133);
  }
  if (settingDate) // box to set dates when switching to free choice mode
    rect(width - 147, 135, 144, 363);

  // draw the text for user instructions
  textAlign(RIGHT, TOP);
  fill(waveColour);
  text("Real time\nPast month\nFree choice\nPoseidon", width - 48, 18);
  textAlign(LEFT, TOP);
  fill(epicentreColour2);
  text("R\nM\nF\nP", width - 38, 18);

  // add features in Poseidon mode
  if (state == 4) {

    // sentence
    text("You are Poseidon, God of the Sea and Earthshakes, and your wrath has no limits.", 10, 10);

    // click markers
    fill(waveColour);
    text("click.", 29, 35);
    text("cliiick.", 274, 35);
    text("cliiiiiiiiick.", 519, 35);
    fill(epicentreColour2);
    ellipse(14, 46, 4, 4);
    ellipse(257, 45, 8, 8);
    ellipse(500, 44, 12, 12);

    // graph lines
    line(width - 260, 27, width - 260, 97); 
    line(width - 260, 97, width - 180, 97);

    // X axis label
    fill(waveColour);
    text("Anger", width - 239, 100);
    fill(epicentreColour2);
    text("←            →", width - 260, 100);

    // Y axis label
    pushMatrix();
    translate(width - 284, 105);
    rotate(-HALF_PI);
    fill(waveColour);
    text("Might", 21, 0);
    fill(epicentreColour2);
    text("←            →", 0, 0);
    popMatrix();

    // graph marker
    float poseidonX = map(widthModifier, -1.5, 1.5, width - 260, width - 180);
    float poseidonY = map(waveModifier, 0, 2, 97, 27);
    ellipse(poseidonX, poseidonY, 6, 6);
  }

  // add box for dates in free choice mode
  if (settingDate) {

    // dates
    textAlign(LEFT, TOP);
    fill(waveColour);
    text("\nd\nm\ny\n\n\nd\nm\ny\n\nPress\nwhen ready", width - 113, 151);
    text("\n"+str(day[0])+"\n"+str(month[0])+"\n"+str(year[0])+"\n\n\n"
      +str(day[1])+"\n"+str(month[1])+"\n"+str(year[1]), width - 89, 151);
    fill(epicentreColour2);
    text("From\n\n\n\n\nTo\n\n\n\n\n          Enter", width - 113, 151);

    // arrow marker
    for (int i = 1; i <= 3; i++) {
      if (dateBeingChanged == i)
        text("→", width - 135, 153 + 28 * i);
    }
    for (int i = 4; i <= 6; i++) {
      if (dateBeingChanged == i)
        text("→", width - 135, 209 + 28 * i);
    }
  }

  // display error message if there are no events in the online data
  if (errorMessage) {
    fill(backgroundColour);
    rectMode(CENTER);
    rect(width/2, height/2, 350, 48);
    rectMode(CORNER);
    textAlign(CENTER, CENTER);
    fill(waveColour);
    text("That didn't work... Try changing the dates!", width/2, height/2);
  }
}

void keyPressed() {
  // change state depending on key pressed
  if (key == 'r' || key == 'R') {
    // display loading box
    fill(backgroundColour);
    rectMode(CENTER);
    rect(width/2, height/2, 350, 48);
    rectMode(CORNER);
    textAlign(CENTER, CENTER);
    fill(waveColour);
    text("Loading", width/2, height/2);
    // change state
    state = 1; // real time
    changingState = true;
  }
  if (key == 'm' || key == 'M') {
    // display loading box
    fill(backgroundColour);
    rectMode(CENTER);
    rect(width/2, height/2, 350, 48);
    rectMode(CORNER);
    textAlign(CENTER, CENTER);
    fill(waveColour);
    text("Loading", width/2, height/2);
    // change state
    state = 2; // past month
    changingState = true;
  }  
  if (key == 'p' || key == 'P') {
    state = 4; // Poseidon
    changingState = true;
  }
  if (key == 'b' || key == 'B') {
    state = 5; // not in UI - this is a JSON backup in case the database goes down
    changingState = true;
  }
  if (key == 'f' || key == 'F') {
    settingDate = true; // temporary state to set date before switching to state 3
    dateBeingChanged = 1; // reset tracker for date being changed
  }  

  // if in Poseidon mode and not setting dates, use arrows to change value of modifiers
  if (state == 4 && !settingDate) {
    if (keyCode == LEFT && widthModifier >= -1.4)
      widthModifier -= .15;
    if (keyCode == RIGHT && widthModifier <= 1.4)
      widthModifier += .15;
    if (keyCode == DOWN && waveModifier >= .09)
      waveModifier -= .1;
    if (keyCode == UP && waveModifier <= 1.91)
      waveModifier += .1;
  }

  // in any state, if setting dates, use arrows to change days, months and years
  if (settingDate) {

    // right and left arrows to adjust days, months and years
    for (int i = 0; i <= 1; i++) {
      if (dateBeingChanged == 1 + 3 * i) {
        if (keyCode == LEFT && day[i] >= 2)
          day[i]--;
        if (keyCode == RIGHT && day[i] <= 30)
          day[i]++;
      }
      if (dateBeingChanged == 2 + 3 * i) {
        if (keyCode == LEFT && month[i] >= 2)
          month[i]--;
        if (keyCode == RIGHT && month[i] <= 11)
          month[i]++;
      }
      if (dateBeingChanged == 3 + 3 * i) {
        if (keyCode == LEFT && year[i] >= 1901)
          year[i]--;
        if (keyCode == RIGHT && year[i] <= 2018)
          year[i]++;
      }
    }

    // up and down arrows to change which parameter is being adjusted
    if (keyCode == UP && dateBeingChanged >= 2)
      dateBeingChanged--;
    if (keyCode == DOWN && dateBeingChanged <= 5)
      dateBeingChanged++;

    // Enter key to lock the dates and switch to state 3
    if (keyCode == ENTER) {
      // display loading box
      fill(backgroundColour);
      rectMode(CENTER);
      rect(width/2, height/2, 350, 48);
      rectMode(CORNER);
      textAlign(CENTER, CENTER);
      fill(waveColour);
      text("Loading", width/2, height/2);
      // change state
      state = 3; // free choice
      changingState = true;
    }
  }
}

void mousePressed() {
  // track when mouse is pressed down in Poseidon mode
  if (state == 4)
    clickOnset = millis();
}

void mouseReleased() {
  // in Poseidon mode
  if (state == 4) { 

    // change magnitude of created earthquake depending on click duration
    float clickDuration = constrain(millis() - clickOnset, 0, 1000); // 1 sec maximum
    float magnitude = map(clickDuration, 0, 1000, -1, 10);

    // change coordinates depending on mouse position
    float longitude = map(mouseX, 0, width, -170, 190);
    float latitude = map(mouseY, 0, height, 83, -55); 

    // add a new instance of SingleEvent
    earthquakes.add(new SingleEvent(magnitude, longitude, latitude));
  }
}