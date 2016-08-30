addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');

hdr_image_name='AllHalfValues.exr';
hdr_image=exrread(hdr_image_name);
hdr_info=exrinfo(hdr_image_name);
disp(hdr_info);
disp(hdr_info.attributes);

%ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));
%ldr_image=tonemap(hdr_image);

% figure();
% subplot(1,2,1);
% imshow(ldr_image);
% %set(gca,'Visible','off')
% title('LDR Image (EXR Tone Mapping)');
% 
% %Convert to HDR
% hdr_out=zeros(size(ldr_image),'single'); %32 bits - single precision floating point
% 
% 
% 
% 
