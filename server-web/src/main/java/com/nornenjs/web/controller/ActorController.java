package com.nornenjs.web.controller;

import com.nornenjs.web.actor.Actor;
import com.nornenjs.web.actor.ActorInfo;
import com.nornenjs.web.actor.ActorService;
import com.nornenjs.web.util.ValidationUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.validation.BindingResult;
import org.springframework.validation.Errors;
import org.springframework.validation.Validator;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;


/**
 * Created by Francis on 2015-04-22.
 */
@Controller
public class ActorController {
    
    private static Logger logger = LoggerFactory.getLogger(ActorController.class);
    
    @Autowired
    private ActorService actorService;
    
    @RequestMapping(value ={"/", "/signIn"}, method = RequestMethod.GET)
    public String signInPage() {
        return "user/signIn";
    }

    @RequestMapping(value = "/noPermission", method = RequestMethod.GET)
    public String permissionPage() {
        return "user/noPermission";
    }
    
    @RequestMapping(value = "/join", method = RequestMethod.GET)
    public String joinPage(Model model){
        model.addAttribute("actorInfo", new ActorInfo());
        return "user/join";
    }
    
    @RequestMapping(value = "/join", method = RequestMethod.POST)
    public String joinPost(@ModelAttribute ActorInfo actorInfo, BindingResult result){
        new ActorInfoJoinValidator().validate(actorInfo, result);
        if(result.hasErrors()){
            return "user/join";
        }else{
            actorService.createActor(actorInfo);
            logger.debug(actorInfo.toString());
            return "redirect:/";
        }
    }
    
    @RequestMapping(value = "/forgotPassword", method = RequestMethod.GET)
    public String forgotPasswordPage(Model model){
        model.addAttribute("actorInfo", new ActorInfo());
        return "user/forgotPassword";
    }
    
    @RequestMapping(value = "/forgotPassword", method = RequestMethod.POST)
    public String forgotPassword(@ModelAttribute ActorInfo actorInfo){
        logger.debug(actorInfo.toString());
        return "redirect:/forgotPassword";
    }
    
    @RequestMapping(value = "/myInfo", method = RequestMethod.GET)
    public String myInfoPage(Model model){
        model.addAttribute("actor", new ActorInfo(new Actor("username", "qwertyuijhgfd23456789@!@", true), "myemail@nornenjs.com", "성근", "김", "2015-04-30", "2015-04-31"));
        return "user/myInfo";
    }

    @RequestMapping(value = "/setting", method = RequestMethod.GET)
    public String settingPage() {
        return "user/setting";
    }


    private class ActorInfoJoinValidator implements Validator{

        @Override
        public boolean supports(Class<?> aClass) {
            return ActorInfo.class.isAssignableFrom(aClass);
        }

        @Override
        public void validate(Object object, Errors errors) {
            ActorInfo actorInfo = (ActorInfo) object;
            Actor actor = actorInfo.getActor();

            String username = actor.getUsername();
            if(ValidationUtil.isNull(username)){
                errors.rejectValue("actor.username", "actorInfo.actor.username.empty");
            }else{
                if(ValidationUtil.isUsername(username)){
                    errors.rejectValue("actor.username", "actorInfo.actor.username.wrong");
                }else{
                    if(actorService.selectUsernameExist(username)){
                        errors.rejectValue("actor.username", "actorInfo.actor.username.exist");
                    }
                }
            }

            String password = actor.getPassword();
            if(ValidationUtil.isNull(password)){
                errors.rejectValue("actor.password", "actorInfo.actor.password.empty");
            }else{
                if(ValidationUtil.isPassword(password)){
                    errors.rejectValue("actor.password", "actorInfo.actor.password.wrong");
                }
            }

            String email = actorInfo.getEmail();
            if(ValidationUtil.isNull(email)){
                errors.rejectValue("email", "actorInfo.email.empty");
            }else{
                if(ValidationUtil.isEmail(email)){
                    errors.rejectValue("email", "actorInfo.email.wrong");
                }else{
                    if(actorService.selectEmailExist(email)){
                        errors.rejectValue("email", "actorInfo.email.exist");
                    }
                }
            }

            String firstName = actorInfo.getFirstName();
            if(ValidationUtil.isNull(firstName)){
                errors.rejectValue("firstName", "actorInfo.firstName.empty");
            }else{
                if(ValidationUtil.isChar(firstName)){
                    errors.rejectValue("firstName", "actorInfo.firstName.wrong");
                }
            }

            String lastName = actorInfo.getLastName();
            if(ValidationUtil.isNull(lastName)){
                errors.rejectValue("lastName", "actorInfo.lastName.empty");
            }else{
                if(ValidationUtil.isChar(lastName)){
                    errors.rejectValue("lastName", "actorInfo.lastName.wrong");
                }
            }
        }
    }
}