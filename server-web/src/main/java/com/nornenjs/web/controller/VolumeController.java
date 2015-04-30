package com.nornenjs.web.controller;

import com.nornenjs.web.data.DataService;
import com.nornenjs.web.util.ValidationUtil;
import com.nornenjs.web.volume.Volume;
import com.nornenjs.web.volume.VolumeFilter;
import com.nornenjs.web.volume.VolumeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.validation.Errors;
import org.springframework.validation.Validator;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

/**
 * Created by Francis on 2015-04-26.
 */
@Controller
@PreAuthorize("hasRole('ROLE_DOCTOR')")
@RequestMapping(value = "/volume")
public class VolumeController {
    
    private static Logger logger = LoggerFactory.getLogger(VolumeController.class);
    
    @Autowired
    private VolumeService volumeService;
    
    @Autowired
    private DataService dataService;

    @RequestMapping(value = "/", method = RequestMethod.GET)
    public void whyThisIsCall(){

    }
    
    @RequestMapping(value = "/{volumePn}", method = RequestMethod.GET)
    public String listPage(@PathVariable Integer volumePn){
        logger.debug(volumePn.toString());
        return "volume/one";
    }
    
    @RequestMapping(value = "/list", method = RequestMethod.GET)
    public String listPage(@ModelAttribute VolumeFilter volumeFilter){
        logger.debug(volumeFilter.toString());
        return "volume/list";
    }
    
    @RequestMapping(value = "/upload", method = RequestMethod.GET)
    public String uploadPage(Model model){
        model.addAttribute("volume", new Volume());
        return "volume/upload";
    }

    @RequestMapping(value = "/upload", method = RequestMethod.POST)
    public String uploadPost(Model model, @ModelAttribute Volume volume, BindingResult result) {
        new Validator(){
            @Override
            public boolean supports(Class<?> aClass) {
                return Volume.class.isAssignableFrom(aClass);
            }

            @Override
            public void validate(Object object, Errors errors) {
                Volume volume = (Volume) object;
                
                Integer volumeDataPn = volume.getVolumeDataPn();
                if(volumeDataPn == null){
                    errors.rejectValue("volumeDataPn", "volume.volumeDataPn.empty");
                }
                
                Integer width = volume.getWidth();
                if(width == null){
                    errors.rejectValue("width", "volume.width.empty");
                }
                
                Integer height = volume.getHeight();
                if(height == null){
                    errors.rejectValue("height", "volume.height.empty");
                }
                
                Integer depth = volume.getDepth();
                if(depth == null){
                    errors.rejectValue("depth", "volume.depth.empty");
                }
                
                String title = volume.getTitle();
                if(ValidationUtil.isNull(title)){
                    errors.rejectValue("title", "volume.title.empty");
                }
                
            }
        }. validate(volume, result);
        
        if (result.hasErrors()) {
            model.addAttribute("data", dataService.selectOne(volume.getVolumeDataPn()));
            return "volume/upload";
        }else{
            User user = (User) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
            String username = user.getUsername();
            volume.setUsername(username);
            volumeService.insert(volume);
            return "redirect:/volume/list";   
        }
    }
    
}
