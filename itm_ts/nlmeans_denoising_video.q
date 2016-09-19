%==============================================================================
% nlmeans_denoising_video.q
%==============================================================================
% Non-local means algorithm, according to the paper:
% B. Goossens, H. Luong, J. Aelterman, A. Pizurica and W. Philips, 
% "A GPU-accelerated real-time NLMeans algorithm for denoising color video 
% sequences, " Int. Conf. Advanced Concepts for Intelligent Vision Systems 
% (ACIVS 2010), Dec. 13-16, Sydney, Australia, p. 46-57.
% ---
% NOTE: I still need to make a few changes to this code in order to fully
% implement the above paper.
%==============================================================================
% 2011-2013 Bart Goossens
%==============================================================================
import "system.q"
import "inttypes.q"
import "colored_noise.q"
import "linalg.q"

% Function:
% denoise_nlmeans - video filter
%
% Parameters:
% img_noisy - noisy input image. This can either be an RGB image or a
%                     grayscale image
% img_den - frame buffer to store the denoised image
% sigma - estimated noise standard deviation
% search_wnd - size of the search window used for block matching
% half_block_size - half the size of the local patch
% correlated_noise - remove correlated noise
%
% Remarks:
% - This filter is the non-vector based version (which is fast enough to 
%   work in real-time). For the best denoising performance, use the
%   vector-based version from nlmeans_denoising_stillimages.q
function [] = denoise_nlmeans( _
    img_noisy : cube, _
    img_den : cube, _
    sigma : scalar, _
    search_wnd : int, _
    half_block_size : int, _
    correlated_noise : int = 0)

    % bandwidth parameter
    h = -0.045 / (sigma^2 * 3)

    [rows,cols,C] = size(img_noisy)

    %if correlated_noise
    %    img_prewhit = irealfft2(fft2(img_noisy)./repmat(sqrt(max(1e-4,PS)),[1,1,C]))
    %    %imshow(fftshift2(1./sqrt(max(1e-2,PS))),[])
    %    imshow(img_prewhit,[])
    %    h = h / 5
    %else
        img_prewhit = img_noisy
    %endif

    % computation of the square difference
    function y = square_diff(x, d : vec)
        function [] = __kernel__ process_rgb(x : cube'circular, y : cube'unchecked, d : ivec2, pos : ivec2)
            diff1 = (x[pos[0],pos[1],0..3]) - (x[pos[0]+d[0],pos[1]+d[1],0..3])
            diff2 = (x[pos[0],pos[1],0..3]) - (x[pos[0]+d[0],pos[1]+d[1]+1,0..3])
            diff3 = (x[pos[0],pos[1],0..3]) - (x[pos[0]+d[0]+1,pos[1]+d[1],0..3])
            diff4 = (x[pos[0],pos[1],0..3]) - (x[pos[0]+d[0]+1,pos[1]+d[1]+1,0..3])
            y[pos[0],pos[1],0..3] = [dotprod(diff1, diff1),
                                     dotprod(diff2, diff2),
                                     dotprod(diff3, diff3),
                                     dotprod(diff4, diff4)]
        end

        y = zeros(size(x,0),size(x,1),4)
        parallel_do(size(y),x,y,d[0..1],process_rgb)
    end

    % A cyclic mean filter - (without normalization)
    function [] = moving_average_filter(img_in, img_out, half_block_size)
        function [] = __kernel__ mean_filter_hor_cyclic(x : cube'circular, y : cube'unchecked, n : int, pos : ivec2)
            sum = zeros(4)
            for i=pos[1]-n..pos[1]+n
                sum = sum + x[pos[0],i,0..3]
            end
            y[pos[0],pos[1],0..3] = sum
        end

        function [] = __kernel__ mean_filter_ver_cyclic(x : cube'circular, y : cube'unchecked, n : int, pos : ivec2)
            sum = zeros(4)
            for i=pos[0]-n..pos[0]+n
                sum = sum + x[i,pos[1],0..3]
            end
            y[pos[0],pos[1],0..3] = sum
        end

        img_tmp = zeros(size(img_in))
        parallel_do (size(img_out), img_in, img_tmp, half_block_size, mean_filter_hor_cyclic)
        parallel_do (size(img_out), img_tmp, img_out, half_block_size, mean_filter_ver_cyclic)
    end

    % weighting and accumulation step
    function [] = weight_and_accumulate(accum_mtx, accum_weight, img_noisy, ssd, h, d)
        function [] = __kernel__ process_rgb(accum_mtx : cube'unchecked, accum_weight : mat'unchecked, _
                                             img_noisy : cube'circular, ssd : cube'circular, h : scalar, d : ivec2, pos : ivec2)
            dpos = pos + d
            weight1 = exp(h * ssd[pos[0],pos[1],0..3])
            a = weight1[0] * (img_noisy[dpos[0],dpos[1],0..3]) +
                weight1[1] * (img_noisy[dpos[0],dpos[1]+1,0..3]) +
                weight1[2] * (img_noisy[dpos[0]+1,dpos[1],0..3]) +
                weight1[3] * (img_noisy[dpos[0]+1,dpos[1]+1,0..3])
            w = sum(weight1)

            dpos = pos - d
            weight2 = exp(h * ssd[dpos[0],dpos[1],0..3])
            a += weight2[0] * (img_noisy[dpos[0],dpos[1],0..3]) +
                 weight2[1] * (img_noisy[dpos[0],dpos[1]+1,0..3]) +
                 weight2[2] * (img_noisy[dpos[0]+1,dpos[1],0..3]) +
                 weight2[3] * (img_noisy[dpos[0],dpos[1]+1,0..3])
            w += sum(weight2)

            accum_mtx[pos[0],pos[1],0..3] = accum_mtx[pos[0],pos[1],0..3] + a
            accum_weight[pos] = accum_weight[pos] + w    
        end        

        parallel_do(size(img_noisy,0..1),accum_mtx,accum_weight,img_noisy,ssd,h, d, process_rgb)
    end

    accum_mtx = zeros(size(img_noisy))
    accum_weight = zeros(rows,cols)
    ssd = zeros(rows,cols,4)

    for dis_x = -search_wnd..2..search_wnd
        for dis_y = -search_wnd..2..search_wnd
            if dis_x == 0 && dis_y == 0
                % nothing to do here
            elseif (dis_y == 0 && dis_x > 0) || (dis_y > 0)
                square_diff_img = square_diff(img_prewhit, [dis_x,dis_y])
                moving_average_filter(square_diff_img, ssd, half_block_size)
                weight_and_accumulate(accum_mtx, accum_weight, img_noisy, ssd, h, [dis_x,dis_y])
            endif
        end
    end

    % Perform the floating point division (normalization) and convert back to 
    img_den[:,:,:] = accum_mtx ./ repmat(accum_weight,[1,1,C])
end

% Function: make_raw_cube
%
% Converts a floating point cube (with three color components) to the
% 32-bit RGBA (8-bit per pixel) format, as used by video codecs.
%
function [y : cube] = make_raw_cube(x : cube)
    y = cube(size(x,0), size(x,1),4)
    y[:,:,0..2] = x[:,:,[2,1,0]]
end

function [] = main()

    sigma = 25
    search_wnd = 3
    half_block_size = 3
    correlated_noise = 0

    % TODO - still need to put a video stream here...
    img = imread("lena_big.tif")


    if !correlated_noise  % experiment with white noise
        img_noisy = img + sigma * randn(size(img))
    else
        PS = generate_psd(size(img,0..1), psd_ct_ramp_spectrum_noise, 1, 0)        
        img_noisy = img + sigma * cgn_rand(size(img), PS)
    endif

    img_raw = make_raw_cube(img_noisy)
    img_den = cube(size(img_raw))

    tic()
    for k=0..9
    denoise_nlmeans(img_raw, img_den, sigma, search_wnd, half_block_size, correlated_noise)
    end
    toc()

    %imshow(uint8_to_float(img_raw)-uint8_to_float(img_den),[-128,128])
    imshow(img_den,[0,255])

end