//
//  ViewController.swift
//  ActiveLabelDemo
//
//  Created by Johannes Schickling on 9/4/15.
//  Copyright © 2015 Optonaut. All rights reserved.
//

import UIKit
import ActiveLabel

class ViewController: UIViewController {
    
    let label = ActiveLabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let customType = ActiveType.custom(pattern: "are also\\b") //Looks for "are"
        let customType2 = ActiveType.custom(pattern: "\\bit\\b") //Looks for "it"
        let customType3 = ActiveType.custom(pattern: "\\bsupports\\b") //Looks for "supports"
        let customType4 = ActiveType.preview(pattern: "http(?:s?):\\/\\/(?:www\\.)?youtu(?:be\\.com\\/watch\\?v=|\\.be\\/)([\\w\\-\\_]*)(&(amp;)?‌​[\\w\\?‌​=]*)?", preview: "View Video") //Looks for youtube links

//        label.enabledTypes = [.mention, .hashtag, .url, customType, customType2, customType3, customType4]
        label.enabledTypes.append(customType)
        label.enabledTypes.append(customType2)
        label.enabledTypes.append(customType3)
        label.enabledTypes.append(customType4)

        label.urlMaximumLength = 31

        label.customize { label in
            label.text = "This is a 🚂 post with #multiple #hashtags and 😱 a @userhandle. Links are also google.com supported like" +
            " this one: HTTPS://optonaut.co. Now it also supports custom patterns -> are\n\n" +
                "Let's trim a long link: \nhttps://twitter.com/twicket_app/status/649678392372121601\nhttp://youtu.be/iwGFalTRHDA"
            label.numberOfLines = 0
            label.lineSpacing = 4
            label.textColor = UIColor(red: 102.0/255, green: 117.0/255, blue: 127.0/255, alpha: 1)
            label.hashtagColor = UIColor(red: 85.0/255, green: 172.0/255, blue: 238.0/255, alpha: 1)
            label.mentionColor = UIColor(red: 238.0/255, green: 85.0/255, blue: 96.0/255, alpha: 1)
            label.URLColor = UIColor(red: 85.0/255, green: 238.0/255, blue: 151.0/255, alpha: 1)
            label.URLSelectedColor = UIColor(red: 82.0/255, green: 190.0/255, blue: 41.0/255, alpha: 1)

            label.handleMentionTap { self.alert("Mention", message: $0) }
            label.handleHashtagTap { self.alert("Hashtag", message: $0) }
            label.handleURLTap { self.alert("URL", message: $0.absoluteString) }
            
            label.isCopyLinksEnable = true
            //Custom types
            label.underlineStyle[customType] = NSUnderlineStyle.styleSingle.rawValue
            label.customColor[customType] = UIColor.purple
            label.customSelectedColor[customType] = UIColor.green
            
            label.customColor[customType2] = UIColor.magenta
            label.customSelectedColor[customType2] = UIColor.green
            
            label.underlineStyle[customType3] = NSUnderlineStyle.patternDot.rawValue | NSUnderlineStyle.styleSingle.rawValue
            
            label.underlineStyle[customType4] = NSUnderlineStyle.styleSingle.rawValue
            label.customColor[customType4] = UIColor.blue
            
            label.configureLinkAttribute = { (type, attributes, isSelected) in
                var atts = attributes
                switch type {
                case customType3, customType4:
                    atts[NSAttributedStringKey.font] = isSelected ? UIFont.boldSystemFont(ofSize: 16) : UIFont.boldSystemFont(ofSize: 14)
                default: ()
                }
                
                return atts
            }

            label.handleCustomTap(for: customType) { self.alert("Custom type", message: $0) }
            label.handleCustomTap(for: customType2) { self.alert("Custom type", message: $0) }
            label.handleCustomTap(for: customType3) { self.alert("Custom type", message: $0) }
            label.handleCustomTap(for: customType4) { self.alert("Youtube link", message: $0) }
        }

        label.frame = CGRect(x: 20, y: 40, width: view.frame.width - 40, height: 300)
        view.addSubview(label)
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func alert(_ title: String, message: String) {
        let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        vc.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(vc, animated: true, completion: nil)
    }

}

