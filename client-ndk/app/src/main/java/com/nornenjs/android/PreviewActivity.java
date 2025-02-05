package com.nornenjs.android;


import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.*;
import android.view.inputmethod.EditorInfo;
import android.widget.*;
import com.nineoldandroids.view.ViewPropertyAnimator;
import com.nornenjs.android.dto.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;

import java.io.*;
import java.net.HttpURLConnection;

import java.net.URL;
import java.util.*;


public class PreviewActivity extends Activity {

    private static final String TAG = "PreviewActivity";

    private VolumeFilter volumeFilter;
    int pns;


    Volume volumes;
    Data datas;
    List<Bitmap> thumbnails;
    GridView gridview;
    ThumbAdapter thumbAdapter;

    int width, height, depth;
    String savepath = "";
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_preview);

        Intent intent = getIntent();
        pns = intent.getIntExtra("pns",-1);
        if(pns != -1)
        {
            Log.d(TAG, "pns : "+pns);
        }else
        {
            Log.d(TAG, "pns us -1");
        }

        thumbnails = new ArrayList<Bitmap>();

        SharedPreferences pref = getSharedPreferences("userInfo", 0);
        volumeFilter = new VolumeFilter(pref.getString("username",""), "");


        thumbAdapter = new ThumbAdapter(thumbnails, PreviewActivity.this);
        gridview = (GridView) findViewById(R.id.previewlist);
        gridview.setAdapter(thumbAdapter);

        gridview.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {

                Log.d("emitTag", "emit position : " + position);
                Intent intent;
                if(position == 1)
                {
                    Log.d(TAG, "go to JNIActivity");
                    intent = new Intent(PreviewActivity.this, JniGLActivity.class);
                }
                else {
                    Log.d(TAG, "go to MprActivity");
                    intent = new Intent(PreviewActivity.this, MprActivity.class);
                }
                intent.putExtra("width", width);
                intent.putExtra("height", height);
                intent.putExtra("depth", depth);
                intent.putExtra("savepath", savepath);
                intent.putExtra("step", "preview");
                intent.putExtra("datatype", position-1);
                startActivity(intent);
            }
        });

        new PostVolumeImageTask().execute();

        Log.d(TAG, "thumbnails sie : " + thumbnails.size());

    }

    private class PostVolumeImageTask extends AsyncTask<Void, Void, ResponseVolumeInfo> {

        @Override
        protected void onPreExecute() {
            super.onPreExecute();
        }

        @Override
        protected ResponseVolumeInfo doInBackground(Void... params) {

            final String url = getString(R.string.tomcat) + "/mobile/volume/"+volumeFilter.getUsername()+"/"+pns;
            Boolean isSuccess = false;

            ResponseEntity<ResponseVolumeInfo> response = null;

            try {

                RestTemplate restTemplate = new RestTemplate();

                while(!isSuccess) {
                    try{
                        response = restTemplate.postForEntity(url, volumeFilter, ResponseVolumeInfo.class);
                        if(response != null && response.getBody() != null){
                            isSuccess = true;
                        }
                    }catch (ResourceAccessException e){
                        Log.e("Error", e.getMessage(), e);
                        isSuccess = false;
                    }
                }

                return response.getBody();

            } catch (Exception e) {
                Log.e(TAG, e.getMessage(), e);
            }

            return null;
        }

        @Override
        protected void onPostExecute(ResponseVolumeInfo responseVolume) {
            super.onPostExecute(responseVolume);


            volumes = responseVolume.getVolume();
            Log.d(TAG, "volumes : " + volumes.toString());

            List<Integer> thumbnails = responseVolume.getThumbnails();

            width = responseVolume.getVolume().getWidth();
            height = responseVolume.getVolume().getHeight();
            depth = responseVolume.getVolume().getDepth();
            savepath = responseVolume.getData().getSavePath();
            Log.d(TAG, "getData : " + responseVolume.getData().toString());


            thumbAdapter.text = volumes.getTitle();

            new GetThumbnails().execute("" + thumbnails.get(0), "0");
            new GetThumbnails().execute("" + thumbnails.get(1), "1");
            new GetThumbnails().execute("" + thumbnails.get(2), "2");
            new GetThumbnails().execute("" + thumbnails.get(3), "3");

            Log.d(TAG, "after excute()");

            datas = responseVolume.getData();
            Log.d(TAG,"datas : " + datas.toString());

            if(volumes == null)
            {

                Log.d(TAG, "통신이 안된 경우");
            }

        }

    }

    private class GetThumbnails extends AsyncTask<String, Void, Bitmap>{
        int index;
        @Override
        protected Bitmap doInBackground(String... params) {

            Log.d(TAG, "params0 : " + params[0]);
            index = Integer.parseInt(params[1]);
            Bitmap data = downloadImage(getString(R.string.tomcat) + "/data/thumbnail/" + params[0]);

            return data;

        }

        @Override
        protected void onPostExecute(Bitmap bytes) {
            if(bytes != null)
            {
                Log.d(TAG, "add bitmap");
                thumbnails.add(bytes);
            }
            else
                Log.d(TAG, "bitmap is null");

            thumbAdapter.notifyDataSetChanged();
        }
    }

    public Bitmap downloadImage(String imgName) {

        Log.d(TAG, "URI : " + imgName);
        Bitmap bitmap = null;

        try {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            HttpURLConnection con = (HttpURLConnection) ( new URL(imgName)).openConnection();
            con.setDoInput(true);

            con.setRequestProperty("Accept-Encoding", "identity");
            con.connect();

            int responseCode = con.getResponseCode();
            Log.d(TAG, "responseCode : " + responseCode);
            Log.d(TAG, "getContentLength : " + con.getContentLength());

            InputStream is = con.getInputStream();
            bitmap = BitmapFactory.decodeStream(is);

            con.disconnect();
        }
        catch(Throwable t) {
            t.printStackTrace();
        }
        return bitmap;

    }
}
