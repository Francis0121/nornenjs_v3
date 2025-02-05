/**
 * Copyright Francis kim.
 */
var EVENT_MESSAGE = require('./message');
var ENUMS = require('../enums');
var logger = require('../logger');
var Encoding = require('../cuda/encoding').Encoding;

/**
 * Android Event Handler 
 *
 * @param cudaRenderMap
 *  적제된 쿠다 모듈이 있는 Hash map Object
 *  TODO 적제되어 있는 모듈에 대한것을 파라미터로 넘겨주는 상황이 별로 좋지 않아 보임
 * @constructor
 */
var Android = function(cudaRenderMap){
    if(typeof cudaRenderMap !== 'object'){
        throw new Error('Android event handler require client HashMap Object');
    }

    this.encoding = new Encoding();
    this.cudaRenderMap = cudaRenderMap;
    this.socket = null;
};

/**
 * Add socket event handler 
 * @param socket
 *  socket object
 */
Android.prototype.addSocketEventListener = function(socket){
    if(typeof socket !== 'object'){
        throw new Error('Android event handler need socket client object');
    }

    this.socket = socket;
    this.rotationtouchEventListener();
    this.translationtouchEventListener();
    this.pinchzoomtouchEventListener();
    this.pngEventListener();
    this.volumeMPRListener();
    this.otfEventListener();
    this.brightnessEventListener();
};

/**
 * Last encoding image is type png
 * @param socket
 */
Android.prototype.pngEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.PNG, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        if(option.mip == "mip")
            cudaRender.type = ENUMS.RENDERING_TYPE.MIP;
        else
            cudaRender.type = ENUMS.RENDERING_TYPE.VOLUME;


        $this.encoding.Androidpng(cudaRender, socket);
    });
};

/**
 * Touch Event Handler
 * @param socket
 */
Android.prototype.rotationtouchEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.ROTATION, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        if(option.mip == "mip")
            cudaRender.type = ENUMS.RENDERING_TYPE.MIP;

        cudaRender.rotationX = option.rotationX;
        cudaRender.rotationY = option.rotationY;

        $this.encoding.Androidjpeg(cudaRender, socket);
    });

};
Android.prototype.translationtouchEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.TRANSLATION, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        if(option.mip == "mip")
            cudaRender.type = ENUMS.RENDERING_TYPE.MIP;

        cudaRender.positionX = option.positionX;
        cudaRender.positionY = option.positionY;

        $this.encoding.Androidjpeg(cudaRender, socket);
    });

};
Android.prototype.pinchzoomtouchEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.PINCHZOOM, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        if(option.mip == "mip")
            cudaRender.type = ENUMS.RENDERING_TYPE.MIP;

        cudaRender.positionZ = option.positionZ;

        $this.encoding.Androidjpeg(cudaRender, socket);
    });

};
Android.prototype.brightnessEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.BRIGHT, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        cudaRender.brightness = option.brightness;

        $this.encoding.Androidjpeg(cudaRender, socket);
    });

};

Android.prototype.volumeMPRListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.MPR, function(option){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        if(option.mip == "mip")
            cudaRender.type = ENUMS.RENDERING_TYPE.MIP;
        else
            cudaRender.type = ENUMS.RENDERING_TYPE.MPR;

        cudaRender.mprType = option.mprType;
        cudaRender.transferScaleX = option.transferScaleX;
        cudaRender.transferScaleY = option.transferScaleY;
        cudaRender.transferScaleZ = option.transferScaleZ;
        cudaRender.positionZ = option.positionZ;

        if("ok" == option.png)
            $this.encoding.Androidpng(cudaRender, socket);
        else
            $this.encoding.Androidjpeg(cudaRender, socket);
    });

};

Android.prototype.otfEventListener = function(){
    var $this = this,
        socket = this.socket;

    socket.on(EVENT_MESSAGE.ANDROID.OTF, function(otfOption){
        var cudaRender = $this.cudaRenderMap.get(socket.id);

        cudaRender.type = ENUMS.RENDERING_TYPE.VOLUME;
        cudaRender.transferStart = otfOption.start;
        cudaRender.transferMiddle1 = otfOption.middle1;
        cudaRender.transferMiddle2 = otfOption.middle2;
        cudaRender.transferEnd = otfOption.end;
        cudaRender.transferFlag = otfOption.flag

        if(otfOption.flag == 2) {//otfOption.isPng
            $this.encoding.Androidpng(cudaRender, socket);
        }else{
            $this.encoding.Androidjpeg(cudaRender, socket);
        }
    });

};

module.exports.Android = Android;