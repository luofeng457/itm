% Conversion script EXR to TIFF files
% Authors: Gonzalo Luzardo, Hiep Luong
clear all

dir_in_name =  '/media/gluzardo/Data/Stuttgart/showgirl_02/';
dir_out_name = '/media/gluzardo/Data/Stuttgart/showgirl_02_out/';

exr_files = dir(strcat(dir_in_name,'*.exr'));

nr = length(exr_files);

% Compute minimum and maximum over the whole video sequencefireplace_out
mi = 2^16;
ma = 0;
for i = 1:nr
    disp(strcat(strcat('Phase 1: reading file ',exr_files(i).name),'...'));
    im = exrread(strcat(dir_in_name,exr_files(i).name));
    
    mi = min(mi,min(im(:)));
    ma = max(ma,max(im(:)));
end
mami= ma - mi;

% TIFF parameters
tagstruct.ImageLength = size(im,1);
tagstruct.ImageWidth = size(im,2);
tagstruct.Photometric = Tiff.Photometric.RGB;
tagstruct.BitsPerSample = 16;
tagstruct.SamplesPerPixel = 3;
tagstruct.SampleFormat = 1;
% tagstruct.SMaxSampleValue = double(ma);
% tagstruct.SMinSampleValue = double(mi);
tagstruct.Compression = 1;
tagstruct.RowsPerStrip = size(im,2);
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Software = 'MATLAB';  

for i = 1:nr
      
      im = exrread(strcat(dir_in_name,exr_files(i).name));
      tiff_path = strcat(dir_out_name,exr_files(i).name(1:end-3));
      disp(strcat(strcat('Phase 2: Writing TIFF file ',exr_files(i).name(1:end-3)),'...'));
      
      tiff_file_path = strcat(dir_out_name,strcat(exr_files(i).name(1:end-3),'tiff'));
      disp(strcat('Writing',tiff_file_path));
      
      t = Tiff(tiff_file_path,'w');
      t.setTag(tagstruct)
      
      data_n = (im - mi)./mami; %Normalized
      data_e = data_n.^(1/6.5);
      
      data = uint16((2^16)*data_e); 
      t.write(data);
      t.close
end
