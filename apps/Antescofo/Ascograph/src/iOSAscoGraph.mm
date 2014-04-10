//
//  iOSAscoGraph.mm
//  AscoGraph
//
//  Created by Thomas Coffy on 29/03/14.
//  Copyright (c) 2014 IRCAM. All rights reserved.
//

#include "iOSAscoGraph.h"
//#include "ofxTLAntescofoSim.h"
#include "ofxColorPicker.h"
#include "ofxUI.h"
#include "ofxOSC.h"
#include "ofxConsole.h"

#include "Function.h"
#include "Environment.h"

bool _debug = true;

extern ofxConsole* console;

iOSAscoGraphMenu* guiMenu;


// callback for traces... unused yet.
void ascograph_send_action_trace(const string& action_name, const string& fathername, double now, double rnow, const string& s) {}
void ascograph_send_cont_trace(const string& action_name, const string& fathername, double now, double rnow, double s) {}



void AntescofoTimeline::setZoomer(ofxTLZoomer *z)
{
	//XXX if (zoomer) removeTrack(zoomer);
	delete zoomer;
	zoomer = z;
	zoomer->setTimeline(this);
	zoomer->setup();
    //zoomer->setDrawRect(ofRectangle(offset.y, tabs->getBottomEdge(), width, 160));

	bringTrackToTop(zoomer);
	bringTrackToTop(zoomer);
}


//--------------------------------------------------------------
void iOSAscoGraph::setup(){
    //ofSetDataPathRoot("../Resources/data");
    //ofSetDataPathRoot(".");
    
    ofEnableSmoothing();
	ofEnableAlphaBlending();
    //ofSetFrameRate(24);
#if 0
	//glewExperimental=TRUE;
	GLenum err=glewInit();
	if(err!=GLEW_OK)
	{
		//Problem: glewInit failed, something is seriously wrong.
		cout<<"glewInit failed, aborting."<<endl;
		abort();
	}
#endif
    // settings menu
    guiMenu = [[iOSAscoGraphMenu alloc] initWithNibName:@"iOSAscoGraphMenu" bundle:nil];
	[ofxiOSGetGLView() addSubview:guiMenu.view];
    guiMenu.view.hidden = true;
    
	console = new ofxConsole(4, 500, 800, 300, 10);

    score_x = 5;
	score_y = 82;
	mUIbottom_y = 40;
    
	bpm = 120;
    
	ofSetEscapeQuitsApp(false);
	score_w = ofGetWindowWidth() - score_x - 5;
	score_h = ofGetWindowHeight()/3;

    ofSetOrientation(OF_ORIENTATION_90_LEFT);
	ofSetVerticalSync(true);
	
    ofxAntescofoZoom = new ofxTLZoomer2D();
	ofxAntescofoNote = new ofxTLAntescofoNote(this);
	ofxAntescofoBeatTicker = new ofxTLBeatTicker(this);
    setupTimeline();
    
	setupUI();

    setupBonjour();

	setupOSC();
    
    TEXT_CONSTANT_TEMP_ACTION_FILENAME = ofxNSStringToString(NSTemporaryDirectory()) + "ascograph_tmp.asco.txt";
    TEXT_CONSTANT_TEMP_FILENAME = ofxNSStringToString(NSTemporaryDirectory()) + "tmpfile-ascograph.txt";
    
	remove(TEXT_CONSTANT_TEMP_FILENAME.c_str());
	remove(TEXT_CONSTANT_TEMP_ACTION_FILENAME.c_str());
    
	drawCache.allocate(ofGetWidth(), ofGetHeight(), GL_RGBA);
	drawCache.begin();
	ofClear(255,255,255, 0);
	drawCache.end();
    
	//if (mScore_filename.size()) loadScore(mScore_filename, true);

    bShouldRedraw = true;
    bLoadingScore = false;
	bHide = true;
    
    //screenSize = ofToString(w) + "x" + ofToString(h);
    drawBonjour();

}

void iOSAscoGraph::setupOSC(){
    // listen for OSC
	int port = 0;
	/*std::istringstream is(mOsc_port);
	is >> port;
	if (! is.good() && port <= 0)
    */
    mOsc_port = "6789";
	ofLog() << "Listening on OSC port " << mOsc_port << endl;
	try {
		mOSCreceiver.setup(atoi(mOsc_port.c_str()));
	} catch(...) {
		ofSetColor(0, 0, 0, 100);
		ofRect(0, 0, ofGetWindowWidth(), ofGetWindowHeight());
		ofSetColor(255, 255, 255, 240);
        
		string err = "Error can not listen on port ";
		err += port;
		err += " ! Please verify port is available (is another application blocking this UDP port ?";
		cerr << err << endl;
		cout << err << endl;
		ofLog() << err << endl;
		ofDrawBitmapString(err, 100, 300);
		ofxAntescofoNote->set_error(err);
		//TODO guiError->draw();
		//TODO display_error();
	}
    std::istringstream is;
	is.str("");
	is.str(mOsc_port_MAX);
	is.clear();
	is >> port;
	if (! is.good() && port <= 0)
	{
		//cerr << "Not a number, try again." << endl;
		mOsc_port_MAX = "5678";
	}
	//save();
	std::cout << "Connecting OSC on " << mOsc_host << ":"<< atoi(mOsc_port_MAX.c_str()) << endl;
	try {
		mOSCsender.setup(mOsc_host, atoi(mOsc_port_MAX.c_str()));
	} catch (...)
	{ cerr << "ERROR OSC EXCEPTION" << endl; }
    
    gettimeofday(&last_draw_time, 0);
}

void iOSAscoGraph::setupUI(){
    guiBottom = new ofxUICanvas(64, 0, score_x+score_w+200 /*- 300*/, score_y);
    guiBottom->setFont("GUI/NewMedia Fett.ttf");
	//ofxUIColor col(188, 189, 203, 255);// = ofxAntescofoNote->color_staves_bg;col.a = 255;
	ofxUIColor col(149, 154, 162, 255);
	
    guiBottom->setColorBack(col);
	mBPMbuffer = new float[256];
	for (int i = 0; i < 256; i++) mBPMbuffer[i] = 0.;
    
	ofxUISpacer *space = new ofxUISpacer(ofGetWidth(), 1);
	space->setVisible(false);
	guiBottom->addWidgetDown(space);
    int fontsize = 10;
	mLabelBPM = new ofxUILabel(TEXT_CONSTANT_BUTTON_BPM, fontsize);
    mLabelBPM->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	//guiBottom->addWidgetSouthOf(mLabelBPM, TEXT_CONSTANT_BUTTON_START);
	guiBottom->addWidgetDown(mLabelBPM);
	mLabelBPM = new ofxUILabel("120", fontsize);
    mLabelBPM->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetEastOf(mLabelBPM, TEXT_CONSTANT_BUTTON_BPM);
    
	mLabelBeat = new ofxUILabel(TEXT_CONSTANT_BUTTON_BEAT, fontsize);
    mLabelBeat->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetSouthOf(mLabelBeat, TEXT_CONSTANT_BUTTON_BPM);
	mLabelBeat = new ofxUILabel("0", fontsize);
    mLabelBeat->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetEastOf(mLabelBeat, TEXT_CONSTANT_BUTTON_BEAT);
    
	mLabelPitch = new ofxUILabel(TEXT_CONSTANT_BUTTON_PITCH, fontsize);
    mLabelPitch->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetSouthOf(mLabelPitch, TEXT_CONSTANT_BUTTON_BEAT);
	mLabelPitch = new ofxUILabel("0", fontsize);
    mLabelPitch->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetEastOf(mLabelPitch, TEXT_CONSTANT_BUTTON_PITCH);
    
	// tempo curve
	ofxUISpectrum* tempoCurve = new ofxUISpectrum(313, 64, mBPMbuffer, 256, 0., 290.0, "bpm");
    tempoCurve->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	//tempoCurve->setDrawOutline(true);
	guiBottom->addWidgetDown(tempoCurve);
	tempoCurve->setColorFill(ofColor(ofxAntescofoNote->color_key));
	tempoCurve->setColorFillHighlight(ofColor(ofxAntescofoNote->color_key));
	ofxUIRectangle* r = tempoCurve->getRect();
	r->x = 3; r->y = 3;
    
	string path_prefix_img = ofFilePath::getCurrentExeDir() + "../Resources/";
    
	// transport btns
    
	int wi = 32;
	int xi = 358, yi = 28, dxi = 12;
	string img_path("GUI/prev_.png");
	ofxUIMultiImageToggle* prevToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_PREV_EVENT);
    prevToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	prevToggle->setLabelVisible(false);
	prevToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(prevToggle, "bpm");
	r = prevToggle->getRect(); r->x = xi; r->y = yi;
    
	img_path = "GUI/stop_.png";
	ofxUIMultiImageToggle* stopToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_STOP);
    stopToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	stopToggle->setLabelVisible(false);
	stopToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(stopToggle, TEXT_CONSTANT_BUTTON_PREV_EVENT);
	r = stopToggle->getRect(); r->x = xi + wi + dxi; r->y = yi;
    
	img_path = "GUI/play_.png";
	ofxUIMultiImageToggle* playToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_PLAY);
    playToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	playToggle->setLabelVisible(false);
	playToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(playToggle, TEXT_CONSTANT_BUTTON_STOP);
	r = playToggle->getRect(); r->x = xi + 2*(wi+dxi); r->y = yi;
    
	img_path = "GUI/start_.png";
	ofxUIMultiImageToggle* startToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_START);
    startToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
    startToggle->setLabelVisible(false);
	startToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(startToggle, TEXT_CONSTANT_BUTTON_PLAY);
	r = startToggle->getRect(); r->x = xi + 3*(wi+dxi); r->y = yi;
    
	img_path = "GUI/next_.png";
	ofxUIMultiImageToggle* nextToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_NEXT_EVENT);
    nextToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
    nextToggle->setLabelVisible(false);
	nextToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(nextToggle, TEXT_CONSTANT_BUTTON_START);
	r = nextToggle->getRect(); r->x = xi + 4*(wi+dxi); r->y = yi;
    

    
	//guiBottom->addWidgetDown(new ofxUISpacer(ofGetWidth()-5, 1));
	ofxUIButton *bu = new ofxUIButton("NOTE", false, 30, 15);
    bu->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetEastOf(bu, "bpm");
	bu->setColorBack(ofxAntescofoNote->color_note);
    
	bu = new ofxUIButton("CHORD", false, 30, 15);
    bu->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetRight(bu);
	bu->setColorBack(ofxAntescofoNote->color_note_chord);
    
	bu = new ofxUIButton("MULTI", false, 30, 15);
    bu->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetRight(bu);
	bu->setColorBack(ofxAntescofoNote->color_note_multi);
    
	bu = new ofxUIButton("TRILL", false, 30, 15);
    bu->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	guiBottom->addWidgetRight(bu);
	bu->setColorBack(ofxAntescofoNote->color_note_trill);

    //guiBottom->addSpacer();
    mDdl_host_lists = new ofxUIDropDownList("Antescofo hosts", antescofo_hostnames);
    guiBottom->addWidgetRight(mDdl_host_lists);
    mDdl_host_lists->setAllowMultiple(false);
    mDdl_host_lists->setAutoClose(true);
    
	img_path = "GUI/settings_.png";
	ofxUIMultiImageToggle* settingsToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_SETTINGS);
    settingsToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
	settingsToggle->setLabelVisible(false);
	settingsToggle->setDrawOutline(true);
	guiBottom->addWidgetEastOf(settingsToggle, TEXT_CONSTANT_BUTTON_SETTINGS);
	r = settingsToggle->getRect(); r->x = ofGetWidth() - 100;//xi + 4*(wi+dxi);
    r->y = 4;
    
    img_path = "GUI/note_.png";
	ofxUIMultiImageToggle* viewToggle = new ofxUIMultiImageToggle(wi, wi, false, img_path, TEXT_CONSTANT_BUTTON_TOGGLEVIEW);
    viewToggle->setFont((ofxUIFont *)&ofxAntescofoNote->mFont);
    viewToggle->setLabelVisible(false);
	viewToggle->setDrawOutline(true);
	guiBottom->addWidgetSouthOf(viewToggle, TEXT_CONSTANT_BUTTON_SETTINGS);
	//r = viewToggle->getRect(); r->x = xi + 4*(wi+dxi); r->y = yi;
    
    ofAddListener(guiBottom->newGUIEvent, this, &iOSAscoGraph::guiEvent);

    cout << "Screen size: " << ofGetWidth() << " x " <<  ofGetHeight() << endl;

}

void iOSAscoGraph::guiEvent(ofxUIEventArgs &e)
{
    string name = e.widget->getName();
    if(name == "Antescofo hosts")
    {
        ofxUIDropDownList *ddlist = (ofxUIDropDownList *) e.widget;
        vector<ofxUIWidget *> &selected = ddlist->getSelected();
        for(int i = 0; i < selected.size(); i++)
        {
            cout << "So in the DynDropdownList we have selected: " << selected[i]->getName() << endl;
            string antescofohost = selected[i]->getName();
            send_OSC_getscore(antescofohost);
        }
    } else if(e.widget->getName() == TEXT_CONSTANT_BUTTON_PLAY)
    {
	    ofxUILabelToggle *b = (ofxUILabelToggle *) e.widget;
	    cout << "Play button change: " << b->getValue() << endl;
	    if (b->getValue() == 1) {
		    ofxOscMessage m;
		    m.setAddress("/antescofo/cmd");
		    /*cout << "mPlayLabel: " << mPlayLabel << endl;
		    if (mPlayLabel.size()) {
			    m.addStringArg("playfrom");
			    m.addStringArg(mPlayLabel);
		    } else*/
			    m.addStringArg("play");
		    mOSCsender.sendMessage(m);
		    b->setValue(false);
	    }
    }
    if(e.widget->getName() == TEXT_CONSTANT_BUTTON_START)
    {
	    ofxUILabelToggle *b = (ofxUILabelToggle *) e.widget;
	    cout << "Start button change: " << b->getValue() << endl;
	    if (b->getValue() == 1) {
		    ofxOscMessage m;
		    m.setAddress("/antescofo/cmd");
		    m.addStringArg("start");
		    m.addStringArg("");
		    mOSCsender.sendMessage(m);
		    b->setValue(false);
	    }
    }
    if(e.widget->getName() == TEXT_CONSTANT_BUTTON_NEXT_EVENT || e.widget->getName() == TEXT_CONSTANT_BUTTON_PREV_EVENT)
    {
	    ofxUILabelToggle *b = (ofxUILabelToggle *) e.widget;
	    cout << "Prev/next event button change: " << b->getValue() << endl;
	    if (b->getValue() == 1) {
		    ofxOscMessage m;
		    m.setAddress("/antescofo/cmd");
		    if (e.widget->getName() == TEXT_CONSTANT_BUTTON_NEXT_EVENT)
			    m.addStringArg("nextevent");
		    if (e.widget->getName() == TEXT_CONSTANT_BUTTON_PREV_EVENT)
			    m.addStringArg("previousevent");
		    mOSCsender.sendMessage(m);
		    b->setValue(false);
	    }
    }
    if(e.widget->getName() == TEXT_CONSTANT_BUTTON_STOP)
	{
		ofxUILabelToggle *b = (ofxUILabelToggle *) e.widget;
		cout << "Stop button change: " << b->getValue() << endl;
        if (b->getValue() == 1) {
            ofxOscMessage m;
            m.setAddress("/antescofo/cmd");
            m.addStringArg("stop");
            //mPlayLabel.clear();
            mOSCsender.sendMessage(m);
            b->setValue(false);
        }
    }
    if(e.widget->getName() == TEXT_CONSTANT_BUTTON_SETTINGS)
	{
		ofxUILabelToggle *b = (ofxUILabelToggle *) e.widget;
		cout << "Settings button change: " << b->getValue() << endl;
        guiMenu.view.hidden = !guiMenu.view.hidden;

    }
    if (e.widget->getName() == TEXT_CONSTANT_BUTTON_TOGGLEVIEW)
    {
        ofxAntescofoNote->toggleView();
    }
}
void iOSAscoGraph::push_tempo_value() {
	static unsigned long long lasttime_pushed = ofGetSystemTimeMicros();
	
	unsigned long long nownow;
	nownow = ofGetSystemTimeMicros();
    
	if (nownow - lasttime_pushed > 50000) {
		lasttime_pushed = nownow;
		// shift buffer values by one to the left
		for (int i = 0; i < 255; i++)
			mBPMbuffer[i] = mBPMbuffer[i+1];
		mBPMbuffer[255] = mOsc_tempo;
	}
}

void iOSAscoGraph::setupTimeline(){
    //ofSetBackgroundAuto(false);
    timeline.setupFont("GUI/NewMedia Fett.ttf", 10);
	timeline.setOffset(ofVec2f(score_x, score_y));
	timeline.setup(); //registers events
    
	timeline.setFrameRate(24);
	timeline.setShowTicker(false);
	timeline.setShowBPMGrid(true);
	timeline.enableSnapToBPM(false);
	timeline.setDurationInSeconds(60);
	//timeline.moveToThread(); //increases accuracy of bang call backs
    
	timeline.setLoopType(OF_LOOP_NORMAL);
	timeline.setBPM(bpm);
	timeline.setLockWidthToWindow(false);
    timeline.getColors().load("GUI/Ascograph.xml");

	// use custom zoomer :
	timeline.addTrack("zoom", ofxAntescofoZoom);
	timeline.setZoomer(ofxAntescofoZoom);
	timeline.addTrack("Beats", ofxAntescofoBeatTicker);
	timeline.addTrack("Notes", ofxAntescofoNote);
	ofxAntescofoNote->setDrawRect(ofRectangle(0, 0, score_w, 400));
    ofxAntescofoNote->color_note.set(255, 0, 0, 255);
    ofxAntescofoNote->color_note_chord.set(0, 255, 0, 255);
    ofxAntescofoNote->color_note_trill.set(0, 0, 255, 255);
    ofxAntescofoNote->color_note_multi.set(255, 255, 0, 255);

    
	ofxAntescofoBeatTicker->setup();
	timeline.setShowTicker(true);
	timeline.setBPM(bpm);
    
	timeline.enable();
	timeline.setFrameBased(false);
	ofxAntescofoNote->enable();
}

void iOSAscoGraph::setupBonjour(){
    // start bonjour
    bonjour = new ofxBonjourIp();
    bonjour->addEventListeners(this); // optional
    
    // find me (server)
    bonjour->startService(); // make device 'discoverable' with defaults.
    //bonjour->startService("_ofxBonjourIp._tcp.", "", 7777, "local");
    
    // find another device (client)- note will not discover itself
    bonjour->discoverService(); // discover other device with defaults.
    //bonjour->discoverService(type, domain);
}

void iOSAscoGraph::drawBonjour(){
    ofSetColor(0);
    
    ofDrawBitmapString("BONJOUR IP: ", 20, 20);
    
    // device name- can use this to connect via osc or udp or tcp
    ofDrawBitmapString("Device name: ", 20, 45);
    ofDrawBitmapStringHighlight(bonjour->getDeviceHostName(), 20, 70);
    
    // device ip- can use this to connect via osc or udp or tcp
    ofDrawBitmapString("Device IP: ", 20, 95);
    ofDrawBitmapStringHighlight(bonjour->getDeviceIp(), 20, 120);
    
    // is connected to a service
    ofDrawBitmapString("Connected to other device: ", 20, 145);
    ofDrawBitmapStringHighlight((bonjour->isConnectedToService()) ? "YES" : "NO", 20, 170);
    
    // device name- can use this to connect via osc or udp or tcp
    ofDrawBitmapString("Other device's name: ", 20, 195);
    ofDrawBitmapStringHighlight(bonjour->getServerHostName(), 20, 220);
    
    // device ip- can use this to connect via osc or udp or tcp
    ofDrawBitmapString("Other device's IP: ", 20, 245);
    ofDrawBitmapStringHighlight(bonjour->getServerIp(), 20, 270);
}


//--------------------------------------------------------------
void iOSAscoGraph::update(){
    bool mHasReadMessages = false;

    // check for waiting messages
	try {
		while( mOSCreceiver.hasWaitingMessages() )
		{
            bShouldRedraw = true;

			// get the next message
			ofxOscMessage m;
			mOSCreceiver.getNextMessage( &m );
			if (_debug) ofLog() << "OSC received: '" << m.getAddress() << endl;
            if(m.getAddress() == "/antescofo/clear_score") {
                current_score.clear();
            }
			else if(m.getAddress() == "/antescofo/current_score_append") {
                if(m.getArgType(0) == OFXOSC_TYPE_STRING){
                    current_score += m.getArgAsString(0);
                }
            } else if(m.getAddress() == "/antescofo/current_score") {
                if(m.getArgType(0) == OFXOSC_TYPE_STRING){
                    current_score += m.getArgAsString(0);
                    loadScore(current_score);
                    bLoadingScore = true;
                    mOsc_host = m.getRemoteIp();
                }
            } else if(m.getAddress() == "/antescofo/tempo" && m.getArgType(0) == OFXOSC_TYPE_FLOAT) {
				mOsc_tempo = m.getArgAsFloat(0);
				if (_debug) cout << "OSC received: tempo: "<< mOsc_tempo << endl;
				bpm = mOsc_tempo;
				//TODO mLabelBPM->setLabel(ofToString(mOsc_tempo));
				//if (bpm) timeline.setBPM(bpm);
				//mSliderBPM->setValue(bpm);
				mHasReadMessages = true;
			} else if(m.getAddress() == "/antescofo/event_beatpos" && m.getArgType(0) == OFXOSC_TYPE_FLOAT){
				mOsc_beat = m.getArgAsFloat(0);
				//TODO mLabelBeat->setLabel(ofToString(mOsc_beat));
				if (_debug) cout << "OSC received: beat: "<< mOsc_beat << endl;
				mHasReadMessages = true;
			} else if(m.getAddress() == "/antescofo/rnow" && m.getArgType(0) == OFXOSC_TYPE_FLOAT){
				mOsc_rnow = m.getArgAsFloat(0);
				//mLabelBeat->setLabel(ofToString(mOsc_rnow));
				if (_debug) cout << "OSC received: rnow: "<< mOsc_rnow << endl;
			} else if(m.getAddress() == "/antescofo/pitch"  && m.getArgType(0) == OFXOSC_TYPE_FLOAT){
				mOsc_pitch = m.getArgAsFloat(0);
				//TODO mLabelPitch->setLabel(ofToString(mOsc_pitch));
				if (_debug) cout << "OSC received: pitch: "<< mOsc_pitch << endl;
				mHasReadMessages = true;
			} else {
				// unrecognized message: display it
				string msg_string;
				msg_string = m.getAddress();
				msg_string += ": ";
				for(int i = 0; i < m.getNumArgs(); i++){
					// get the argument type
					msg_string += m.getArgTypeName(i);
					msg_string += ":";
					// display the argument - make sure we get the right type
					if(m.getArgType(i) == OFXOSC_TYPE_INT32){
						msg_string += ofToString(m.getArgAsInt32(i));
					}
					else if(m.getArgType(i) == OFXOSC_TYPE_FLOAT){
						msg_string += ofToString(m.getArgAsFloat(i));
					}
					else if(m.getArgType(i) == OFXOSC_TYPE_STRING){
						msg_string += m.getArgAsString(i);
					}
					else{
						msg_string += "unknown";
					}
				}
				cout << "OSC received: unknown msg: "<< msg_string << endl;
			}
			//no break in order to eat every available messages
        }
	} catch (exception& e) {
		cerr << "OSC HasWaitingMessage exception raised" <<  endl;
	}
    
	// if we read something, advance playhead
	if (mHasReadMessages) {
		mLastOSCmsgDate = ofGetSystemTime();
		if (mOsc_beat != -1 ) {
			fAntescofoTimeSeconds = ofxAntescofoNote->convertAntescofoOutputToTime(mOsc_beat, mOsc_tempo, mOsc_pitch);
            
			if (_debug) cout << "Moving playHead to beat:"<<mOsc_beat << " tempo:"<<mOsc_tempo << " => "<<fAntescofoTimeSeconds << "sec"<<endl;
		}
		mHasReadMessages = false;
		bShouldRedraw = true;
	}
    push_tempo_value();

}

//--------------------------------------------------------------
void iOSAscoGraph::draw(){

    struct timeval now;
	gettimeofday(&now, 0);
#define DRAW_MAX_DELTA_USEC	10000
	if ((now.tv_sec*1000000L + now.tv_usec) - (last_draw_time.tv_sec*1000000L + last_draw_time.tv_usec) < DRAW_MAX_DELTA_USEC) {
		return;
	}
	gettimeofday(&last_draw_time, 0);
	if (!bShouldRedraw) {
        drawCache.draw(0, 0);
    }else {
        ofSetColor(255, 255, 255, 255);
        drawCache.begin();
        ofClear(255,255,255, 0);
        ofPushStyle();

        ofBackgroundGradient(ofColor::white, ofColor::gray);
        timeline.draw();
        ofPopStyle();
        
        drawCache.end();
        
        drawCache.draw(0, 0);
        bShouldRedraw = false;
    }
}

//--------------------------------------------------------------
void iOSAscoGraph::exit(){
}


void iOSAscoGraph::loadScore(string score)
{
    ofxAntescofoNote->clear_error();

    ofLog() << "iOSAscoGraph::loadScore: " << score << endl;
    
    bool res = ofxAntescofoNote->loadscoreAntescofo_fromString(score, TEXT_CONSTANT_TEMP_FILENAME);
    
    if (res) {
        // jumps track
        showJumpTrack();
        
        bShouldRedraw = true;
    }
}


void iOSAscoGraph::showJumpTrack() {
#if 0
	// check if we need to show jump tracks:
	bool bShowJumpTrack = false;
	vector<ofxTLAntescofoNoteOn*>& switches = ofxAntescofoNote->getSwitches();
	for (vector<ofxTLAntescofoNoteOn*>::iterator i = switches.begin();
         i!= switches.end(); i++)
		if ((*i)->jump_dests.size()) {
			bShowJumpTrack = true;
			break;
		}
    
	if (!bShowJumpTrack) {
		if (ofxJumpTrack) timeline.removeTrack(ofxJumpTrack);
		if (ofxJumpTrack) delete ofxJumpTrack;
		ofxJumpTrack = NULL;
		return;
	}
    
	if (ofxJumpTrack == 0) {
		ofxJumpTrack = new ofxTLBeatJump(this);
		timeline.addTrack("Jumps", ofxJumpTrack);
		timeline.bringTrackToPos(ofxJumpTrack, 2);
	}
    
	ofxJumpTrack->setZoomBounds(ofxAntescofoZoom->getViewRange());
	ofxJumpTrack->clear_jumps();
    
	// for every events
	switches = ofxAntescofoNote->getSwitches();
	for (vector<ofxTLAntescofoNoteOn*>::iterator i = switches.begin();
         i!= switches.end(); i++) {
		// for every jump dest
		for (int n = 0; n < (*i)->jump_dests.size(); n++) {
			float destBeat = (*i)->jump_dests[n];
			cout << "showJumpTrack: adding jump: beat:" << (*i)->beat.min << " destBeat:" << destBeat << " label:" << (*i)->label <<endl;
			ofxJumpTrack->add_jump((*i)->beat.min, destBeat, "");
		}
	}
#endif
}






//--------------------------------------------------------------
void iOSAscoGraph::touchDown(ofTouchEventArgs & touch){
    bShouldRedraw = true;
}

//--------------------------------------------------------------
void iOSAscoGraph::touchMoved(ofTouchEventArgs & touch){
    bShouldRedraw = true;

    static int lastx = 0;
    
    cout << "touchMoved:" << touch.x << ", " << touch.y << " xspeed=" << touch.xspeed << endl;
    if (ofxAntescofoNote->getBounds().inside(touch.x, touch.y)) {
        ofxTLZoomer2D *zoom = (ofxTLZoomer2D*)timeline.getZoomer();
        
		ofRange z = zoom->getViewRange();
		ofRange oldz = z;
		//cout << endl << "pos:"<< pos <<" got zoomrange: "<< z.min << "->"<< z.max;
		// continuous scrolling : keep playhead on center
        
		if (1) {
			float c = z.center();
			float d = ((lastx - touch.x) * 0.01) - c;
            
			z.min = ofClamp(z.min + d, 0, 1); z.max = ofClamp(z.max + d, 0, 1);
			if (z.min == .0 && z.span() < oldz.span())
				z.max = oldz.max - oldz.min;
			if (z.max == 1. && z.span() < oldz.span())
				z.min = z.max - oldz.max + oldz.min;
            
            
			//cout <<" to zoomrange: "<< z.min << "->"<< z.max<<endl;
			zoom->setViewRange(z);
			//zoom->setSelectedRange(z);
			//zoom->setViewRange(z);
            
			//lastpos = pos;
		}
    }
    lastx = touch.x;
}

//--------------------------------------------------------------
void iOSAscoGraph::touchUp(ofTouchEventArgs & touch){
    bShouldRedraw = true;

}

//--------------------------------------------------------------
void iOSAscoGraph::touchDoubleTap(ofTouchEventArgs & touch){
    bShouldRedraw = true;

}

//--------------------------------------------------------------
void iOSAscoGraph::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void iOSAscoGraph::lostFocus(){
    
}

//--------------------------------------------------------------
void iOSAscoGraph::gotFocus(){
    
}

//--------------------------------------------------------------
void iOSAscoGraph::gotMemoryWarning(){
    
}

//--------------------------------------------------------------
void iOSAscoGraph::deviceOrientationChanged(int newOrientation){
    bShouldRedraw = true;

}

// Bonjour events handlers
void iOSAscoGraph::onPublishedService(const void* sender, string &serviceIp) {
    ofLog() << "Received published service event: " << serviceIp;
}

void iOSAscoGraph::onDiscoveredService(const void* sender, string &serviceIp) {
    ofLog() << "Received discovered service event: " << serviceIp;
    antescofo_hostnames.push_back(serviceIp);
    mDdl_host_lists->addToggle(serviceIp);
    //send_OSC_getscore();
}

void iOSAscoGraph::onRemovedService(const void* sender, string &serviceIp) {
    ofLog() << "Received removed service event: " << serviceIp;
    if (mDdl_host_lists->getToggles().size() > 0)
        mDdl_host_lists->removeToggle(serviceIp);
}

void iOSAscoGraph::send_OSC_getscore(string host) {
    mOsc_host = host;
    if (mOsc_host.size()) {
        std::cout << "Connecting OSC on " << mOsc_host << ":"<< atoi(mOsc_port_MAX.c_str()) << endl;
        try {
            mOSCsender.setup(mOsc_host, atoi(mOsc_port_MAX.c_str()));
        } catch (...)
        { cerr << "ERROR OSC EXCEPTION" << endl; }

        ofxOscMessage m;
        m.setAddress("/antescofo/cmd");
        bLoadingScore = false;
        ofLog() << "Sending OSC get_current_score..." << endl;
        current_score.clear();
        m.addStringArg("get_current_score");
        mOSCsender.sendMessage(m);
    }
}

void iOSAscoGraph::setAutoscroll(bool newstate)
{
    cout << "AutoScroll changer to " << newstate << endl;
    ofxAntescofoNote->setAutoScroll(newstate);
}


