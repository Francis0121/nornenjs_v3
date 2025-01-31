#include "sio_client.h"
#include "socket_io_client.hpp"

#include <functional>
#include <iostream>
#include <mutex>
#include <condition_variable>
#include <string>
#include <pthread.h>
#include <unistd.h>
#include <sstream>
#include <image_util.h>

#define QSIZE 5
#define LOG_TAG "socket.io.client"

using namespace sio;
using namespace std;

std::mutex _lock;
std::condition_variable_any _cond;
bool connect_finish = false;

unsigned char * bufferQue[6];
int count = -1;

class connection_listener
{
    sio::client &handler;

public:

    connection_listener(sio::client& h):handler(h)
    {
    	dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io client call constructor");
    }

    void on_connected()
    {
        _lock.lock();
        _cond.notify_all();
        connect_finish = true;
        _lock.unlock();
        dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io client connect");
    }

    void on_close(client::close_reason const& reason)
    {
        dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io client closed");
    }

    void on_fail()
    {
        dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io client failed");
    }
};

extern "C" {
	/**
	 * LOOP FLAG - Terminater application - while statement finish
	 */
	void turn_off_flag()
	{
		LOOP_FLAG = 0;
	}
}

extern "C" {
	sio::client h;
}

extern "C" {

	void socket_io_client(void *object)
	{
		err = -9;//초기화
		dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io function start");

		Evas_Object *evas_object = (Evas_Object *)object;
		connection_listener l(h);
		h.set_connect_listener(std::bind(&connection_listener::on_connected, &l));
		h.set_close_listener(std::bind(&connection_listener::on_close, &l,std::placeholders::_1));
		h.set_fail_listener(std::bind(&connection_listener::on_fail, &l));
		h.connect("http://112.108.40.166:5000");

		_lock.lock();
		if(!connect_finish)
		{
			_cond.wait(_lock);
		}
		_lock.unlock();
		dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io connect finish");

		// ~ CUDA Memory Initialize
		h.emit("tizenInit", "");
		dlog_print(DLOG_VERBOSE, LOG_TAG, "Emit \"tizenInit\" message\n");

		// ~ After Memory Init. Do First tizen request image
		h.bind_event("loadCudaMemory",[&](string const& name, message::ptr const& data, bool isAck,message::ptr &ack_resp){//message
			_lock.lock();

			dlog_print(DLOG_VERBOSE, LOG_TAG, "Launched load cuda memory \n");

			// ~ Tizen Requset
			h.emit("tizenQuality", "");

			_lock.unlock();
		});

		h.bind_event("tizenJpeg", [&](string const& name, message::ptr const& data, bool isAck,message::ptr &ack_resp){//message
			_lock.lock();

			int size = data->get_map()["stream"]->get_map()["size"]->get_int();
			shared_ptr<const string> s_binary = data->get_map()["stream"]->get_map()["buffer"]->get_binary();
			string buffer = *s_binary;
			char* textBuf = NULL;
			textBuf = (char *)buffer.c_str();//함수화 하기

			err = -9;
			sizeBuf = size;//순서?

			unsigned int decodeBufSize;

			err = image_util_decode_jpeg_from_memory((unsigned char *)textBuf, sizeBuf, IMAGE_UTIL_COLORSPACE_RGBA8888, &image, &bufWidth, &bufHeight, &decodeBufSize);

			que_in(image);

			if(!err)//IMAGE_UTIL_ERROR_NONE != error
			{
				if(count == QSIZE)
					fresh_que();
			}

			_lock.unlock();
		});

		dlog_print(DLOG_VERBOSE, LOG_TAG, "Bind event listener\n");

		while(LOOP_FLAG){}

		dlog_print(DLOG_VERBOSE, LOG_TAG, "Socket.io function close");
	}
}


extern "C" {
	void emit_quality(){
		h.emit("tizenQuality", "");
	}
}

extern "C"{
	void emit_otf(float otf){
		std::ostringstream otfbuf;
		otfbuf << otf;

		std::string json = "{ \"otf\" : \"" + otfbuf.str()+ "\", \"transferFlag\" : \"1\" }";
		h.emit("tizenOtf", json);
	}
}

extern "C" {
	void emit_otf_end(float otf){
		std::ostringstream otfbuf;
		otfbuf << otf;

		std::string json = "{ \"otf\" : \"" + otfbuf.str()+ "\", \"transferFlag\" : \"2\" }";
		h.emit("tizenOtf", json);
	}
}

extern "C"{
	void emit_brightness(float brightness){
		std::ostringstream brightnessbuf;
		brightnessbuf << brightness;

		std::string json = "{ \"brightness\" : \"" + brightnessbuf.str()+ "\" } ";
		h.emit("tizenBrightness", json);
	}
}

extern "C" {
	int rotationRequestCount = 0;

	void emit_rotation(float rotationX, float rotationY){
		if(rotationRequestCount == 100){
			rotationRequestCount = 0;
			return;
		}

		if( (rotationRequestCount++)%3 != 0 ){
			return;
		}

		std::ostringstream rotationXbuf;
		rotationXbuf << rotationX;

		std::ostringstream rotationYbuf;
		rotationYbuf << rotationY;

		std::string json = "{ \"rotationX\" : \"" + rotationXbuf.str() +"\", \"rotationY\" : \"" + rotationYbuf.str() + "\" } ";
		h.emit("tizenRotation", json);
	}
}


extern "C" {
	int zoomRequestCount = 0;

	void emit_zoom(float positionZ){
		if(zoomRequestCount == 100){
			zoomRequestCount = 0;
			return;
		}

		if( (zoomRequestCount++)%3 != 0 ){
			return;
		}

		std::ostringstream positionZbuf;
		positionZbuf << positionZ;

		std::string json = "{ \"positionZ\" : \"" + positionZbuf.str() +"\" } ";
		h.emit("tizenZoom", json);
	}
}

extern "C" {
	void fresh_que()
	{
		for(int i = 0; i < 5; i++)
		{
			free(bufferQue[i]);
			bufferQue[i] = NULL;
		}
		bufferQue[0] = bufferQue[5];
		count = -1;
	}
}

extern "C" {
	void que_in(unsigned char * inputBuf)
	{
		bufferQue[++count] = inputBuf;
	}
}

extern "C" {
	unsigned char * que_pop()
	{
		return image;
	}
}

extern "C" {
	void free_que()
	{
		for(int i = 0; i < 6; i++)//or count
		{
			if(bufferQue[i])
			{
				free(bufferQue[i]);
				bufferQue[i] = NULL;
			}
		}
	}
}

