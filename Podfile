platform :ios, '13.0'

use_frameworks!

target 'ARTrailer' do
	pod 'TesseractOCRiOS', '4.0.0'
    pod 'YoutubeDirectLinkExtractor'
    pod 'Alamofire', '~> 5.2'
    pod 'SwiftyJSON', '~> 4.0'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'TesseractOCRiOS' 
            target.build_configurations.each do |config|
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
            header_phase = target.build_phases().select do |phase|
                phase.is_a? Xcodeproj::Project::PBXHeadersBuildPhase
            end.first

            duplicated_header_files = header_phase.files.select do |file|
                file.display_name == 'config_auto.h'
            end

            duplicated_header_files.each do |file|
                header_phase.remove_build_file file
            end
        end
    end
end
