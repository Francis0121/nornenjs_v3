package com.nornenjs.android.dto;

import java.util.List;

/**
 * Created by hyok on 15. 5. 8.
 */
public class Volume {
    private Integer pn;

    private String username;

    private Integer volumeDataPn;

    private String title;

    private Integer width;

    private Integer height;

    private Integer depth;

    private String inputDate;

    private String thumbnailPns;

    private List<Integer> thumbnailPnList;

    public Volume() {
    }

    public Volume(String username, Integer volumeDataPn, String title, Integer width, Integer height, Integer depth) {
        this.username = username;
        this.volumeDataPn = volumeDataPn;
        this.title = title;
        this.width = width;
        this.height = height;
        this.depth = depth;
    }

    public void setThumbnailPns(String thumbnailPns) {
        this.thumbnailPns = thumbnailPns;
    }

    public String getThumbnailPns() {
        return thumbnailPns;
    }


    public Integer getPn() {
        return pn;
    }

    public void setPn(Integer pn) {
        this.pn = pn;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public Integer getVolumeDataPn() {
        return volumeDataPn;
    }

    public void setVolumeDataPn(Integer volumeDataPn) {
        this.volumeDataPn = volumeDataPn;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public Integer getWidth() {
        return width;
    }

    public void setWidth(Integer width) {
        this.width = width;
    }

    public Integer getHeight() {
        return height;
    }

    public void setHeight(Integer height) {
        this.height = height;
    }

    public Integer getDepth() {
        return depth;
    }

    public void setDepth(Integer depth) {
        this.depth = depth;
    }

    public String getInputDate() {
        return inputDate;
    }

    public void setInputDate(String inputDate) {
        this.inputDate = inputDate;
    }

    public List<Integer> getThumbnailPnList() {
        return thumbnailPnList;
    }

    public void setThumbnailPnList(List<Integer> thumbnailPnList) {
        this.thumbnailPnList = thumbnailPnList;
    }

    @Override
    public String toString() {
        return "Volume{" +
                "pn=" + pn +
                ", username='" + username + '\'' +
                ", volumeDataPn=" + volumeDataPn +
                ", title='" + title + '\'' +
                ", width=" + width +
                ", height=" + height +
                ", depth=" + depth +
                ", inputDate='" + inputDate + '\'' +
                ", thumbnailPns='" + thumbnailPns + '\'' +
                ", thumbnailPnList=" + thumbnailPnList +
                '}';
    }
}
