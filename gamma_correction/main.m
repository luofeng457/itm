addpath('/u/gluzardo/Documents/phd/openexr-matlab-master');
addpath('/u/gluzardo/Documents/phd/subaxis');

hdr_folder='/u/gluzardo/Documents/phd/itm/ldr_images/ldr_pfstools/hdr/';
ldr_folder='/u/gluzardo/Documents/phd/itm/ldr_images/ldr_pfstools/ldr_mai11/';
image_name='nancy_church_1';

hdr_image=exrread(strcat(hdr_folder,image_name,'.exr'));
hdr_info=exrinfo(strcat(hdr_folder,image_name,'.exr'));
disp(hdr_info);
disp(hdr_info.attributes);

%ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));
ldr_image=tonemap(hdr_image);

%Convert to HDR, gamma correction
[hdr_out,curve]=ldr2hdr_gammacorrection(ldr_image,1);

figure();
subaxis(1,1,1,'M',0.02,'MT',0.05,'MB',0.06);
imshow(ldr_image);
title('LDR Image');

%Draw channels
figure()
subaxis(2,2,4,'M',0.02,'MT',0.05,'MB',0.06);
plot(curve);
axis([0 255 0 500])
title('Transformation curve');
exrwrite(hdr_out,'hdr_out.exr');
disp('HDR image saved');

%Display in false 
clims = [0 100];
subaxis(2,2,1)
imagesc(hdr_out(:,:,1),clims);
axis equal; axis off;
title('Channel B');
colorbar

subaxis(2,2,2)
imagesc(hdr_out(:,:,2),clims);
title('Channel G');
axis equal; axis off;
colorbar

subaxis(2,2,3)
imagesc(hdr_out(:,:,3),clims);
title('Channel R');
axis equal; axis off;
colorbar



