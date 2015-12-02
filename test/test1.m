addpath('/u/gluzardo/Documents/phd/openexr-matlab-master')

hdr_folder='/u/gluzardo/Documents/phd/apps_dev/ldr_images/ldr_pfstools/hdr/';
ldr_folder='/u/gluzardo/Documents/phd/apps_dev/ldr_images/ldr_pfstools/ldr_mai11/';
image_name='forest_path'

hdr_image=exrread(strcat(hdr_folder,image_name,'.exr'));
ldr_image=imread(strcat(ldr_folder,image_name,'.jpg'));

figure();
subplot(1,2,1);
image(ldr_image);



