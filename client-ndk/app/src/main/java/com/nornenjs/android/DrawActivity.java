package com.nornenjs.android;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.*;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import com.fasterxml.jackson.databind.deser.std.DateDeserializers;

import java.util.jar.Attributes;


public class DrawActivity extends View{

    private final String TAG="DrawActivity";
    private final Path figure = new Path();
    private final Path bg = new Path();
    private final Path line = new Path();

    public float tr_x = 350, tr_y = 100, tl_x = 700, tl_y =100, br_x = 800, br_y, bl_x = 250, bl_y;
    //tr_y, tl_y 고정

    public float otf_width, otf_height;

    Point bottomLeft ,bottomRight, topRight, topLeft;
    boolean b_Left ,b_Right, t_Right, t_Left;

    Line left, top, right;
    boolean left_line, top_line, right_line;

    private final Paint cPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bg_Paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint bg_LinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    DashPathEffect dashPath = new DashPathEffect(new float[]{5,5}, 2);

    public DrawActivity(Context context, AttributeSet att) {
        super(context, att);

        cPaint.setStyle(Paint.Style.FILL);
        cPaint.setColor(Color.DKGRAY);
        cPaint.setStrokeWidth(3);

        bg_Paint.setStyle(Paint.Style.STROKE);
        bg_Paint.setPathEffect(dashPath);
        bg_Paint.setStrokeWidth(3);

        bg_LinePaint.setStyle(Paint.Style.STROKE);
        bg_LinePaint.setColor(Color.BLACK);
        bg_LinePaint.setStrokeWidth(30);

        topLeft = new Point(tr_x, tr_y);//기본값...이 기본값은 유지, 재사용이되야함
        topRight = new Point(tl_x,tl_y);
        bottomLeft = new Point(bl_x, bl_y);
        bottomRight = new Point(br_x, br_y);

        left = new Line(topLeft, bottomLeft);
        top = new Line(topLeft, topRight);
        right = new Line(topRight, bottomRight);


        figure.addCircle(topLeft.x, topLeft.y, topLeft.radius, Path.Direction.CW);
        figure.addCircle(topRight.x, topRight.y, topRight.radius, Path.Direction.CW);
        figure.addCircle(bottomLeft.x, bottomLeft.y, bottomLeft.radius, Path.Direction.CW);
        figure.addCircle(bottomRight.x, bottomRight.y, bottomRight.radius, Path.Direction.CW);//점 4개




    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        if(otf_width == 0 || otf_width == 0.0f)
        {
            Log.d("onDraw", "otf_width is 0");
            View layoutMainView = (View)this.findViewById(R.id.canvas);

            otf_width = layoutMainView.getWidth();
            otf_height = layoutMainView.getHeight();

            bottomLeft.setY(otf_height - 100);
            bottomRight.setY(otf_height - 100);
        }
        drawBackground(canvas);


    }



    public void drawBackground(Canvas canvas)
    {

        //점선
        canvas.drawLine(70, 100, otf_width - 70, 100, bg_Paint);

        //기준선 2개
        bg_LinePaint.setColor(Color.BLACK);
        bg_LinePaint.setStrokeWidth(15);
        canvas.drawLine(100, 30, 100, otf_height - 30, bg_LinePaint);
        canvas.drawLine(50, otf_height - 100, otf_width - 70, otf_height - 100, bg_LinePaint);

        //사다리꼴 3개 라인
        bg_LinePaint.setColor(Color.LTGRAY);
        bg_LinePaint.setStrokeWidth(30);
        canvas.drawLine(topLeft.x, topLeft.y, bottomLeft.x, bottomLeft.y, bg_LinePaint);
        canvas.drawLine(topLeft.x, topLeft.y, topRight.x, topRight.y, bg_LinePaint);
        canvas.drawLine(topRight.x, topRight.y, bottomRight.x, bottomRight.y, bg_LinePaint);

        //꼭지점 4개
        canvas.drawCircle(topLeft.x, topLeft.y, topLeft.radius, cPaint);
        canvas.drawCircle(topRight.x, topRight.y, topRight.radius, cPaint);
        canvas.drawCircle(bottomLeft.x, bottomLeft.y, bottomLeft.radius, cPaint);
        canvas.drawCircle(bottomRight.x, bottomRight.y, bottomRight.radius, cPaint);

    }

    float beforeX;
    @Override
    public boolean onTouchEvent(MotionEvent event) {

        Log.d(TAG, "onTouchEvent on DrawActivity");

        if(event.getAction() == MotionEvent.ACTION_DOWN) {

            if(topLeft.checkPoint(event.getX(), event.getY()))
            {

                t_Left = true;
            }
            else if(topRight.checkPoint(event.getX(), event.getY()))
            {

                t_Right = true;
            }
            else if(bottomLeft.checkPoint(event.getX(), event.getY()))
            {

                b_Left = true;
            }
            else if(bottomRight.checkPoint(event.getX(), event.getY()))
            {

                b_Right = true;
            }
            else if(left.IsOnLine(event.getX(), event.getY()))
            {
                beforeX = event.getX();
                left_line = true;
                Log.d("IsOnLine","left line clicked");
            }
            else if(right.IsOnLine(event.getX(), event.getY()))
            {
                beforeX = event.getX();
                right_line = true;
                Log.d("IsOnLine","right line clicked");
            }
            else if(top.IsOnLine(event.getX(), event.getY()))
            {
                beforeX = event.getX();
                top_line = true;
                Log.d("IsOnLine","top line clicked");
            }
            return true;
        }else if(event.getAction() == MotionEvent.ACTION_MOVE) {


            if(t_Left)
            {
                if(event.getX() >= bottomLeft.x)
                    topLeft.setX(event.getX());
            }
            else if(t_Right)
            {
                if(event.getX() <= bottomRight.x)
                    topRight.setX(event.getX());
            }
            else if(b_Left)
            {
                if(event.getX() <= topLeft.x)
                    bottomLeft.setX(event.getX());
            }
            else if(b_Right)
            {
                if(event.getX() >= topRight.x)
                    bottomRight.setX(event.getX());
            }
            else if(left_line)
            {
                topLeft.setX(topLeft.getX() + (-1)*(beforeX - event.getX()));
                bottomLeft.setX(bottomLeft.getX() + (-1)*(beforeX - event.getX()));
                beforeX = event.getX();

            }
            else if(top_line)
            {

                topLeft.setX(topLeft.getX() + (-1)*(beforeX - event.getX()));
                topRight.setX(topRight.getX() + (-1)*(beforeX - event.getX()));
                bottomLeft.setX(bottomLeft.getX() + (-1)*(beforeX - event.getX()));
                bottomRight.setX(bottomRight.getX() + (-1)*(beforeX - event.getX()));
                beforeX = event.getX();
            }
            else if(right_line)
            {

                topRight.setX(topRight.getX() + (-1)*(beforeX - event.getX()));
                bottomRight.setX(bottomRight.getX() + (-1)*(beforeX - event.getX()));
                beforeX = event.getX();
            }
            invalidate();
        }
        else if(event.getAction() == MotionEvent.ACTION_UP)
        {
            if(t_Left)
            {
                t_Left = false;
            }
            else if(t_Right)
            {
                t_Right = false;
            }
            else if(b_Left)
            {
                b_Left = false;
            }
            else if(b_Right)
            {
                b_Right = false;
            }
            else if(left_line)
            {
                left_line = false;
                beforeX = 0;
            }
            else if(top_line)
            {
                top_line = false;
                beforeX = 0;
            }
            else if(right_line)
            {
                right_line = false;
                beforeX = 0;
            }
        }
        return super.onTouchEvent(event);

    }


    class Line
    {
        Point start;
        Point end;

        public Line(Point start, Point end) {
            this.start = start;
            this.end = end;
        }

        public boolean IsOnLine(float checkPointX, float checkPointY)
        {
            float bet_startcheck = (float)Math.sqrt(Math.pow(Math.abs(start.x - checkPointX), 2) + Math.pow(Math.abs(start.y - checkPointY), 2));//distance a
            float bet_startend = (float)Math.sqrt(Math.pow(Math.abs(start.x - end.x), 2) + Math.pow(Math.abs(start.y - end.y), 2));// distance c
            float bet_endcheck = (float)Math.sqrt(Math.pow(Math.abs(end.x - checkPointX), 2) + Math.pow(Math.abs(end.y - checkPointY), 2));//distance b

            double calc = (Math.pow(bet_endcheck, 2) + Math.pow(bet_startend,2) - Math.pow(bet_startcheck,2))/(2*bet_startend*bet_endcheck);
            if(Math.acos(calc) < 0.15)
                    return true;

            return false;
        }

    }

    class Point
    {
        float x,y;
        int radius;

        public Point(float x, float y) {
            this.x = x;
            this.y = y;
            radius = 25;
        }

        public float getX() {
            return x;
        }

        public float getY() {
            return y;
        }

        public int getRadius() {
            return radius;
        }

        public void setX(float x) {
            this.x = x;
        }

        public void setY(float y) {
            this.y = y;
        }

        public boolean checkPoint(float x, float y){
            if((x - (this.x + this.radius)) * (x - (this.x + this.radius)) + (y - (this.y + this.radius)) * (y - (this.y + this.radius)) <= (this.radius+10) * (this.radius+10))
            {
                return true;
            }

            return false;
        }

    }

}
