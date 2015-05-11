/*
 * Copyright 1993-2014 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

// Simple 3D volume renderer

#ifndef _VOLUMERENDER_KERNEL_CU_
#define _VOLUMERENDER_KERNEL_CU_

#include <helper_cuda.h>
#include <helper_math.h>

typedef unsigned int  uint;
typedef unsigned char uchar;

cudaArray *d_volumeArray = 0;
cudaArray *d_blockArray = 0;
cudaArray *d_transferFuncArray;
cudaArray *d_TF2dArray = 0;
//cudaArray *d_transferFuncArray1 = 0;

typedef unsigned char VolumeType;
//typedef unsigned short VolumeType;

texture<VolumeType, 3, cudaReadModeNormalizedFloat> tex;         // 3D texture
texture<VolumeType, 3, cudaReadModeNormalizedFloat> tex_block;         // 3D texture

texture<float4, 1, cudaReadModeElementType>         transferTex; // 1D transfer function texture
texture<float4, 1, cudaReadModeElementType>         transferTex1; // 1D transfer function texture
texture<float4, 3, cudaReadModeElementType> tex_TF2d;		//pre-integral
typedef struct
{
    float4 m[3];
} float3x4;

__constant__ float3x4 c_invViewMatrix;  // inverse view matrix

struct Ray
{
    float3 o;   // origin
    float3 d;   // direction
};

// intersect ray with a box
// http://www.siggraph.org/education/materials/HyperGraph/raytrace/rtinter3.htm

__device__
int intersectBox(Ray r, float3 boxmin, float3 boxmax, float *tnear, float *tfar)
{
    // compute intersection of ray with all six bbox planes
    float3 invR = make_float3(1.0f) / r.d;
    float3 tbot = invR * (boxmin - r.o);
    float3 ttop = invR * (boxmax - r.o);

    // re-order intersections to find smallest and largest on each axis
    float3 tmin = fminf(ttop, tbot);
    float3 tmax = fmaxf(ttop, tbot);

    // find the largest tmin and the smallest tmax
    float largest_tmin = fmaxf(fmaxf(tmin.x, tmin.y), fmaxf(tmin.x, tmin.z));
    float smallest_tmax = fminf(fminf(tmax.x, tmax.y), fminf(tmax.x, tmax.z));

    *tnear = largest_tmin;
    *tfar = smallest_tmax;

    return smallest_tmax > largest_tmin;
}
__device__ unsigned char myMAX(unsigned char a, unsigned char b)
{
	if(a >= b)
		return a;
	else 
		return b;
}
__device__ 
float3 cudaNormalize(float3 a){
	float3 temp={a.x, a.y, a.z};
	float sum = sqrt((float)(a.x*a.x + a.y*a.y + a.z*a.z));

	if(sum == 0){
		temp.x = 0;
		temp.y = 0;
		temp.z = 0;
	}else{
		temp.x /= sum;
		temp.y /= sum;
		temp.z /= sum;
	}

	return temp;
}

// transform vector by matrix (no translation)
__device__
float3 mul(const float3x4 &M, const float3 &v)
{
    float3 r;
    r.x = dot(v, make_float3(M.m[0]));
    r.y = dot(v, make_float3(M.m[1]));
    r.z = dot(v, make_float3(M.m[2]));
    return r;
}

// transform vector by matrix with translation
__device__
float4 mul(const float3x4 &M, const float4 &v)
{
    float4 r;
    r.x = dot(v, M.m[0]);
    r.y = dot(v, M.m[1]);
    r.z = dot(v, M.m[2]);
    r.w = 1.0f;
    return r;
}

__device__ uint rgbaFloatToInt(float4 rgba)
{
    rgba.x = __saturatef(rgba.x);   // clamp to [0.0, 1.0]
    rgba.y = __saturatef(rgba.y);
    rgba.z = __saturatef(rgba.z);
    rgba.w = __saturatef(rgba.w);
    return (uint(rgba.w*255)<<24) | (uint(rgba.z*255)<<16) | (uint(rgba.y*255)<<8) | uint(rgba.x*255);
}
__device__ uchar rgbaFloatToChar(float rgba)
{
	rgba = __saturatef(rgba);   // clamp to [0.0, 1.0]
	return (uchar(rgba*255));
}
__global__ void makeBlock_kernel(unsigned char* image_p, unsigned char* dest_p, cudaExtent blockSize, cudaExtent volumeSize)
{
	int tx = __umul24(blockIdx.x, blockDim.x) + threadIdx.x;
    int ty = __umul24(blockIdx.y, blockDim.y) + threadIdx.y;
	if (tx >= blockSize.width || ty >= blockSize.height) return;

	for(int i=0; i<blockSize.depth; i++){
		dest_p[i*blockSize.width*blockSize.height + ty*blockSize.height + tx] = 0;
		unsigned char tempmax=0;

		for(int z=i*4; z<=i*4+4; z++)
			for(int y=ty*4; y<=ty*4+4; y++)
				for(int x=tx*4; x<=tx*4+4; x++){
					if(z>=volumeSize.depth || y>=volumeSize.height || x>=volumeSize.width )
						continue;
					tempmax = myMAX(tempmax, image_p[z*volumeSize.width*volumeSize.height + y*volumeSize.height + x]);
				}
		dest_p[i*blockSize.width*blockSize.height + ty*blockSize.height + tx] = tempmax;
	}
}
__global__ void
d_render(uint *d_output, uint imageW, uint imageH,
         float density, float brightness,
         float transferOffset, float transferScale)
{
    const int maxSteps = 500;
    const float tstep = 0.01f;
    const float opacityThreshold = 0.95f;
    const float3 boxMin = make_float3(-1.0f, -1.0f, -1.0f);
    const float3 boxMax = make_float3(1.0f, 1.0f, 1.0f);

    uint x = blockIdx.x*blockDim.x + threadIdx.x;
    uint y = blockIdx.y*blockDim.y + threadIdx.y;

    if ((x >= imageW) || (y >= imageH)) return;

    float u = (x / (float) imageW)*2.0f-1.0f;
    float v = (y / (float) imageH)*2.0f-1.0f;

		
    // calculate eye ray in world space
    Ray eyeRay;
    eyeRay.o = make_float3(mul(c_invViewMatrix, make_float4(0.0f, 0.0f, 0.0f, 1.0f)));
    eyeRay.d = normalize(make_float3(u, v, -2.0f));
    eyeRay.d = mul(c_invViewMatrix, eyeRay.d);

    // find intersection with box
    float tnear, tfar;
    int hit = intersectBox(eyeRay, boxMin, boxMax, &tnear, &tfar);

    if (!hit) return;

    if (tnear < 0.0f) tnear = 0.0f;     // clamp to near plane

    // march along ray from front to back, accumulating color
    float4 sum = make_float4(0.0f);
	float4 temp =make_float4(0.0f);
	//uint4 sum = make_uint4(0);
    float t = tnear;
    float3 pos = eyeRay.o + eyeRay.d * tnear;
    float3 step = eyeRay.d*tstep;
	
	float max = 0.0f; 
	float3 lV = eyeRay.d;
    for (float i=0; i<maxSteps; i++)
    {
        // read from 3D texture
        // remap position to [0, 1] coordinates

	    float block_den = (tex3D(tex_block, (pos.x*0.5f+0.5f), (pos.y*0.5f+0.5f), (pos.z*0.5f+0.5f)));
		//float3 advanced = {0.0f,0.0f.0.0f};
		//uint density = __float2uint_rn(block_den*256);
		/*temp.w = block_den;
		temp.x = block_den;
		temp.y = block_den;
		temp.z = block_den;
		uint density =  ((unsigned int)(temp.w*255)<<24) | ((unsigned int)(temp.z*255)<<16) | ((unsigned int)(temp.y*255)<<8) | (unsigned int)(temp.x*255);*/
	   //	if(block_den >= max) 
       //				max = block_den;*/
	   float3 advanced  = {0.0f, 0.0f, 0.0f};
	   if(block_den < 65/254) { //빈공간 도약 - PALLET_START~PALLET_END까지만 그리기 때문에
			
	   }
	   else{
			float sample = tex3D(tex, pos.x*0.5f+0.5f, pos.y*0.5f+0.5f, pos.z*0.5f+0.5f);
			float sample_next = tex3D(tex, pos.x*0.5f+0.5+(step.x*0.5), pos.y*0.5f+0.5f +(step.y*0.5),  pos.z*0.5f+0.5f+(step.z*0.5));
	   
			// lookup in transfer function texture
			//float4 col = tex1D(transferTex, sample);
			float4 col = tex3D(tex_TF2d, sample,sample_next,0);
		

			float3 nV = {0.0, 0.0, 0.0};
		
			float x_plus = tex3D(tex, pos.x*0.5f+0.5+(step.x*0.5), pos.y*0.5f+0.5f, pos.z*0.5f+0.5f);
			float x_minus = tex3D(tex,pos.x*0.5f+0.5-(step.x*0.5), pos.y*0.5f+0.5f, pos.z*0.5f+0.5f);

			float y_plus = tex3D(tex, pos.x*0.5f+0.5, pos.y*0.5f+0.5f +(step.y*0.5), pos.z*0.5f+0.5f);
			float y_minus = tex3D(tex, pos.x*0.5f+0.5, pos.y*0.5f+0.5f-(step.y*0.5),pos.z*0.5f+0.5f);

			float z_plus = tex3D(tex, pos.x*0.5f+0.5, pos.y*0.5f+0.5f, pos.z*0.5f+0.5f+(step.z*0.5));
			float z_minus = tex3D(tex, pos.x*0.5f+0.5, pos.y*0.5f+0.5f, pos.z*0.5f+0.5f-(step.z*0.5));

			nV.x = (x_plus - x_minus)/2.0f;
			nV.y = (y_plus - y_minus)/2.0f;
			nV.z = (z_plus - z_minus)/2.0f;

			//nV = cudaNormalize(nV);
			float NL =dot(nV,lV);

			if(NL < 0.0f) NL = 0.0f;
			float localShading = 0.3 + 0.7*NL;
			col*=localShading;

			// pre-multiply alpha
			col.x *= col.w;
			col.y *= col.w;
			col.z *= col.w;

			// "over" operator for front-to-back blending
			sum = sum + col*(1.0f - sum.w);

			// exit early if opaque
			if (sum.w > opacityThreshold)
				break;

			t += (tstep*0.5);

			if (t > tfar) break;

			pos += (step*0.5);
		}
	}
	/*sum.x = max;
	sum.y = max;
	sum.z = max;
	sum.w = 0;*/
    sum *= brightness;

    // write output color
    d_output[y*imageW + x] = rgbaFloatToInt(sum);
	
}

extern "C"
void* make_blockVolume(void* image, cudaExtent blockSize, cudaExtent volumeSize)
{
	unsigned int vsize = volumeSize.width * volumeSize.height * volumeSize.depth * sizeof(VolumeType);
	unsigned int bsize = blockSize.width * blockSize.height * blockSize.depth * sizeof(VolumeType);

	unsigned char *dest; //cpu에 보낼 블락 data
	unsigned char *dest_p; //gpu에서 사용할 블락 데이터
	unsigned char *image_p; //볼륨 데이터

	dest = new unsigned char[bsize/sizeof(VolumeType)]; //64*64*57
	memset((void*)dest, 0, bsize);

	cudaMalloc((void**)&image_p, vsize); 
	cudaMemcpy(image_p, image, vsize, cudaMemcpyHostToDevice); 

	cudaMalloc((void**)&dest_p, bsize);

	dim3 Db = dim3(16, 16);
	dim3 Dg = dim3(8,8);

	makeBlock_kernel<<<Dg, Db>>>(image_p, dest_p, blockSize, volumeSize);

	cudaMemcpy(dest, dest_p, bsize, cudaMemcpyDeviceToHost);
	int max =0;
	int min =1000000;
	for(int i=0; i<64*64*47; i++)
	{
		if(dest[i]>max){
			max =dest[i];
		}
		if(dest[i]<min){
			min =dest[i];
		}
		
	}
	printf("min %d  max %d \n",min,max);
	cudaFree(image_p);
	cudaFree(dest_p);

	return dest;

}
extern "C"
void setTextureFilterMode(bool bLinearFilter)
{
    tex.filterMode = bLinearFilter ? cudaFilterModeLinear : cudaFilterModePoint;
}
extern "C"
void initBlockTexture(void *h_volume_block, int x, int y, int z)
{
	cudaExtent block_Size = make_cudaExtent(x, y, z);
    // create 3D array
    cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<VolumeType>();
    checkCudaErrors( cudaMalloc3DArray(&d_blockArray, &channelDesc, block_Size) );

    // copy data to 3D array
    cudaMemcpy3DParms myParams = {0};
	myParams.srcPtr   = make_cudaPitchedPtr(h_volume_block, block_Size.width*sizeof(VolumeType), block_Size.width, block_Size.height);
    myParams.dstArray = d_blockArray;
    myParams.extent   = block_Size;
    myParams.kind     = cudaMemcpyHostToDevice;
    checkCudaErrors( cudaMemcpy3D(&myParams) );

    // set texture parameters
    tex_block.normalized = true;                      // access with normalized texture coordinates
    tex_block.filterMode = cudaFilterModeLinear;      // linear interpolation
	tex_block.addressMode[0] = cudaAddressModeBorder;   // wrap texture coordinates
    tex_block.addressMode[1] = cudaAddressModeBorder;

	// bind array to 3D texture
    checkCudaErrors(cudaBindTextureToArray(tex_block, d_blockArray, channelDesc));       



	
} 


__global__ void TF2d_kernel(float4* TF2d_k, int TFSize)
{
	int x = __umul24(blockIdx.x, blockDim.x) + threadIdx.x;
    int y = __umul24(blockIdx.y, blockDim.y) + threadIdx.y;

	if(x>=TFSize || y>=TFSize)
		return;

	//float4 result;				//1번 방법 - pre-integral : OTF 뾰족하게 해도 한겹만 나오게 할수있다.
	//float4 temp = {0.0f};
	//
	//if(y > x){
	//	for(int i=x; i<y; i++){
	//		temp = tex1D(tex_TF, i);

	//		float diff = i-x;

	//		if(diff == 0.0f)
	//			diff = 1.0f;

	//		temp.w = 1.0f-pow(1-temp.w, 1/diff);

	//		result.x += (1-result.w)*temp.x*temp.w;
	//		result.y += (1-result.w)*temp.y*temp.w;
	//		result.z += (1-result.w)*temp.z*temp.w;
	//		result.w += (1-result.w)*temp.w;
	//	}
	//}
	//else if(x > y){
	//	for(int i=y; i<x; i++){
	//		temp = tex1D(tex_TF, i);

	//		float diff = i-y;

	//		if(diff == 0.0f)
	//			diff = 1.0f;

	//		temp.w = 1.0f-pow(1-temp.w, 1/diff);

	//		result.x += (1-result.w)*temp.x*temp.w;
	//		result.y += (1-result.w)*temp.y*temp.w;
	//		result.z += (1-result.w)*temp.z*temp.w;
	//		result.w += (1-result.w)*temp.w;
	//	}
	//}
	//else {
	//	result.x = 255.0f;
	//	result.y = 255.0f;
	//	result.z = 255.0f;
	//	result.w = 0.0f;
	//}

	float4 temp;					//2번 방법 - 1번방법보다 물결무늬가 덜 생긴다 : summed 2d table
	float4 result = {0.0};
	float4 sum = {0.0f};
	
	int nx, ny, diff;
	if(x>y){
		diff = x-y;
		ny = x;
		nx = y;
	}
	else if(y>x){
		diff = y-x;
		nx = x;
		ny = y;
	}
	else{
		diff=1;
		nx = ny = x;
		sum.w = 0.0f;
	}

	for(int i=nx; i<ny; i++){
		temp = tex1D(transferTex, i);

		temp.x *= temp.w;
		temp.y *= temp.w;
		temp.z *= temp.w;

		sum.x += temp.x;
		sum.y += temp.y;
		sum.z += temp.z;
		sum.w += temp.w;
	}

	result.x = sum.x / diff; //* (newAlpha/sum.w);
	result.y = sum.y / diff; //* (newAlpha/sum.w);
	result.z = sum.z / diff; //* (newAlpha/sum.w);
	result.w = sum.w / diff;

		

	TF2d_k[TFSize*y + x].x = result.x;
	TF2d_k[TFSize*y + x].y = result.y;
	TF2d_k[TFSize*y + x].z = result.z;
	TF2d_k[TFSize*y + x].w = result.w;


}

//struct OTF_2D* getPre_integration(){
//
//	
//	for(int x=0; x<256; x++){
//		for(int y=0; y<256; y++){
//
//			float4 result;
//			float4 temp={0.0f};
//
//			if(y > x){
//				for(int i=x; i<y; i++){
//					temp.x = transferFunc[i].x;
//					temp.y = transferFunc[i].y;
//					temp.z = transferFunc[i].z;
//					temp.w = transferFunc[i].w;
//					
//					float diff = i-x;
//
//					if(diff == 0.0f)
//						diff = 1.0f;
//
//					temp.w = 1.0f-pow(1-temp.w, 1/diff);
//
//					result.x += (1-result.w)*temp.x*temp.w;
//					result.y += (1-result.w)*temp.y*temp.w;
//					result.z += (1-result.w)*temp.z*temp.w;
//					result.w += (1-result.w)*temp.w;
//				}
//			}
//			else if(x > y){
//				for(int i=y; i<x; i++){
//					temp.x = transferFunc[i].x;
//					temp.y = transferFunc[i].y;
//					temp.z = transferFunc[i].z;
//					temp.w = transferFunc[i].w;
//
//					float diff = i-y;
//
//					if(diff == 0.0f)
//						diff = 1.0f;
//
//					temp.w = 1.0f-pow(1-temp.w, 1/diff);
//
//					result.x += (1-result.w)*temp.x*temp.w;
//					result.y += (1-result.w)*temp.y*temp.w;
//					result.z += (1-result.w)*temp.z*temp.w;
//					result.w += (1-result.w)*temp.w;
//				}
//			}
//			else {
//				result.x = 255.0f;
//				result.y = 255.0f;
//				result.z = 255.0f;
//				result.w = 0.0f;
//			}
//			OTF_2D[256*x + y].sum_R = result.x;
//			OTF_2D[256*x + y].sum_G = result.y;
//			OTF_2D[256*x + y].sum_B = result.z;
//			OTF_2D[256*x + y].sum_a = result.w;
//		}
//	}
//	return OTF_2D;
//}
//int start = 60;
//int end=120;
//
//extern "C"
//void getOTFtable()
//{
//    start++;
//	end++;
//	float4 transferFunc[256];
//	//float4 transferFunc1[256]={0.0f};
//	
//	 for(int i=0; i<=start; i++){    //alpha
//		 transferFunc[i].w = 0.0f;
//		 transferFunc[i].x = 0.0f;
//		 transferFunc[i].y = 0.0f;
//		 transferFunc[i].z = 0.0f;
//	}
//	for(int i=start+1; i<=end; i++){
//		transferFunc[i].w = (1.0 / (start-end)) * ( i - end);
//		transferFunc[i].x = (1.0 / (start-end)) * ( i - end);
//		transferFunc[i].y = (1.0 / (start-end)) * ( i - end);
//		transferFunc[i].z = (1.0 / (start-end)) * ( i - end);
//	}
//	for(int i=end+1; i<256; i++){
//		transferFunc[i].w =1.0f;
//		transferFunc[i].x =1.0f;
//		transferFunc[i].y =1.0f;
//		transferFunc[i].z =1.0f;
//	}
//	
//	//transferFunc1[0].w= transferFunc[0].w;
//	//transferFunc1[0].x= transferFunc[0].x * transferFunc[0].w;
//	//transferFunc1[0].y= transferFunc[0].y * transferFunc[0].w;
//	//transferFunc1[0].z= transferFunc[0].z * transferFunc[0].w;		
//	
//	//for(int i=1; i<256; i++)
//	//{		
//	//	
//
//	//	transferFunc1[i].w += transferFunc1[i-1].w + transferFunc[i].w;
//	//	transferFunc1[i].x += transferFunc1[i-1].x + transferFunc[i].x * transferFunc[i].w;
//	//	transferFunc1[i].y += transferFunc1[i-1].y + transferFunc[i].y * transferFunc[i].w;
//	//	transferFunc1[i].z += transferFunc1[i-1].z + transferFunc[i].z * transferFunc[i].w;
//	//	
//	//	transferFunc1[i].w =(transferFunc1[i].w/256.0f);
//	//	transferFunc1[i].x =(transferFunc1[i].x/256.0f);
//	//	transferFunc1[i].y =(transferFunc1[i].y/256.0f);
//	//	transferFunc1[i].z =(transferFunc1[i].z/256.0f);
//	//	//printf("%f %f\n",transferFunc1[i].w/256,transferFunc1[i].x/256);
//	//	//printf("%f,%f,%f,%f\n",tempA[i],OTF_2Da[before],tempG[i],OTF_2Dg[before]);
//
//	//}
//	//for(int x=0; x<256; x++){
//	//	for(int y=0; y<256; y++){
//
//	//		float4 result;
//	//		float4 temp={0.0f};
//
//	//		if(y > x){
//	//			for(int i=x; i<y; i++){
//	//				temp.x = transferFunc[i].x;
//	//				temp.y = transferFunc[i].y;
//	//				temp.z = transferFunc[i].z;
//	//				temp.w = transferFunc[i].w;
//	//				
//	//				float diff = i-x;
//
//	//				if(diff == 0.0f)
//	//					diff = 1.0f;
//
//	//				temp.w = 1.0f-pow(1-temp.w, 1/diff);
//
//	//				result.x += (1-result.w)*temp.x*temp.w;
//	//				result.y += (1-result.w)*temp.y*temp.w;
//	//				result.z += (1-result.w)*temp.z*temp.w;
//	//				result.w += (1-result.w)*temp.w;
//	//			}
//	//		}
//	//		else if(x > y){
//	//			for(int i=y; i<x; i++){
//	//				temp.x = transferFunc[i].x;
//	//				temp.y = transferFunc[i].y;
//	//				temp.z = transferFunc[i].z;
//	//				temp.w = transferFunc[i].w;
//
//	//				float diff = i-y;
//
//	//				if(diff == 0.0f)
//	//					diff = 1.0f;
//
//	//				temp.w = 1.0f-pow(1-temp.w, 1/diff);
//
//	//				result.x += (1-result.w)*temp.x*temp.w;
//	//				result.y += (1-result.w)*temp.y*temp.w;
//	//				result.z += (1-result.w)*temp.z*temp.w;
//	//				result.w += (1-result.w)*temp.w;
//	//			}
//	//		}
//	//		else {
//	//			result.x = 1.0f;
//	//			result.y = 1.0f;
//	//			result.z = 1.0f;
//	//			result.w = 0.0f;
//	//		}
//	//		OTF_2D[256*x + y].sum_R = result.x;
//	//		OTF_2D[256*x + y].sum_G = result.y;
//	//		OTF_2D[256*x + y].sum_B = result.z;
//	//		OTF_2D[256*x + y].sum_a = result.w;
//	//	}
//	//}
//	//struct OTF_2D *p;
//	//p=getPre_integration();
//	//for(int i=0; i<256; i++)
//	//{
//	//	printf("%f\n",transferFunc1[i].x);
//	//}
//	//-------------------------------------------------------------------
//	// create transfer function texture
//  //  float4 transferFunc[] =
//  //  {
//  //     /* {  0.0, 0.0, 0.0, 0.0, },
//  //      {  1.0, 0.0, 0.0, 1.0, },
//  //      {  1.0, 0.5, 0.0, 1.0, },
//  //      {  1.0, 1.0, 0.0, 1_.0, },
//  //      {  0.0, 1.0, 0.0, 1.0, },
//  //      {  0.0, 1.0, 1.0, 1.0, },
//  //      {  0.0, 0.0, 1.0, 1.0, },
//  //      {  1.0, 0.0, 1.0, 1.0, },
//  //      {  0.0, 0.0, 0.0, 0.0, },*/
//
//		//{  0.0, 0.0, 0.0, 0.0, },
//  //      {  0.0, 0.0, 0.0, 1.0, },
//  //      {  0.0, 0.0, 0.1, 0.2, },
//  //      {  0.3, 0.4, 0.5, 0.6, },
//  //      {  0.7, 0.8, 0.9, 1.0, },
//  //      {  1.0, 1.0, 1.0, 1.0, },
//  //      {  1.0, 1.0, 1.0, 1.0, },
//  //      {  1.0, 1.0, 1.0, 1.0, },
//  //      {  1.0, 1.0, 1.0, 0.0, },
//  //  };
//
//   // create 3D array
//
//	//cudaExtent Size2 = make_cudaExtent(256, 256, 1);
// //   cudaChannelFormatDesc channelDesc3 = cudaCreateChannelDesc<float4>();
// //   checkCudaErrors(cudaMalloc3DArray(&d_transferFuncArray1, &channelDesc3, Size2));
//
// //   // copy data to 3D array
// //   cudaMemcpy3DParms copyParams3 = {0};
// //   copyParams3.srcPtr   = make_cudaPitchedPtr(OTF_2D, Size2.width*sizeof(float4), Size2.width, Size2.height);
// //   copyParams3.dstArray = d_transferFuncArray1;
// //   copyParams3.extent   = Size2;
// //   copyParams3.kind     = cudaMemcpyHostToDevice;
// //   checkCudaErrors(cudaMemcpy3D(&copyParams3));
//
// //   // set texture parameters
// //   tex.normalized = true;                      // access with normalized texture coordinates
// //   tex.filterMode = cudaFilterModeLinear;      // linear interpolation
// //   tex.addressMode[0] = cudaAddressModeBorder;  // clamp texture coordinates
// //   tex.addressMode[1] = cudaAddressModeBorder;
// //   // tex.addressMode[2] = cudaAddressModeBorder;
// //   // bind array to 3D texture
// //   checkCudaErrors(cudaBindTextureToArray(transferTex1, d_transferFuncArray1, channelDesc3));
////////////////////////////////////////////////////////////////////////////////////////////////
//	cudaChannelFormatDesc channelDesc2 = cudaCreateChannelDesc<float4>();
//    cudaArray *d_transferFuncArray;
//    checkCudaErrors(cudaMallocArray(&d_transferFuncArray, &channelDesc2, sizeof(transferFunc)/sizeof(float4), 1));
//    checkCudaErrors(cudaMemcpyToArray(d_transferFuncArray, 0, 0, transferFunc, sizeof(transferFunc), cudaMemcpyHostToDevice));
//
//    transferTex.filterMode = cudaFilterModeLinear;
//    transferTex.normalized = true;    // access with normalized texture coordinates
//    transferTex.addressMode[0] = cudaAddressModeClamp;   // wrap texture coordinates
//
//    // Bind the array to the texture
//    checkCudaErrors(cudaBindTextureToArray(transferTex, d_transferFuncArray, channelDesc2));
//}

extern "C"
void initCuda(void *h_volume, cudaExtent volumeSize)
{
    // create 3D array
    cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<VolumeType>();
    checkCudaErrors(cudaMalloc3DArray(&d_volumeArray, &channelDesc, volumeSize));

    // copy data to 3D array
    cudaMemcpy3DParms copyParams = {0};
    copyParams.srcPtr   = make_cudaPitchedPtr(h_volume, volumeSize.width*sizeof(VolumeType), volumeSize.width, volumeSize.height);
    copyParams.dstArray = d_volumeArray;
    copyParams.extent   = volumeSize;
    copyParams.kind     = cudaMemcpyHostToDevice;
    checkCudaErrors(cudaMemcpy3D(&copyParams));

    // set texture parameters
    tex.normalized = true;                      // access with normalized texture coordinates
    tex.filterMode = cudaFilterModeLinear;      // linear interpolation
    tex.addressMode[0] = cudaAddressModeBorder;  // clamp texture coordinates
    tex.addressMode[1] = cudaAddressModeBorder;
    // tex.addressMode[2] = cudaAddressModeBorder;
    // bind array to 3D texture
    checkCudaErrors(cudaBindTextureToArray(tex, d_volumeArray, channelDesc));

	float4 transferFunc[256];
    int tf_start =65;
	int tf_middle1 =80;
	int tf_middle2=100;
	int tf_end =120;
	
	for(int i=0; i<=tf_start; i++){    //alpha
		 transferFunc[i].w = 0.0f;
		 transferFunc[i].x = 1.0f;
		 transferFunc[i].y = 0.3f;
		 transferFunc[i].z = 0.3f;
	}
	for(int i=tf_start+1; i<=tf_middle1; i++){
		transferFunc[i].w = (1.0 / (tf_middle1-tf_start)) * ( i - tf_start);
		transferFunc[i].x = 1.0 * ( ((1.0 - 1.0) / (tf_middle1-tf_start)) * ( i - tf_start) + 1.0);
		transferFunc[i].y = 0.3 * ( ((1.0 - 0.3) / (tf_middle1-tf_start)) * ( i - tf_start) + 0.3);
		transferFunc[i].z = 0.3 * ( ((1.0 - 0.3) / (tf_middle1-tf_start)) * ( i - tf_start) + 0.3);
	}
	for(int i=tf_middle1+1; i<=tf_middle2; i++){
		transferFunc[i].w =1.0f;
		transferFunc[i].x =1.0f;
		transferFunc[i].y =1.0f;
		transferFunc[i].z =1.0f;
	}
	for(int i=tf_middle2+1; i<=tf_end; i++){
		transferFunc[i].w = (1.0 / (tf_end-tf_middle2)) * (tf_end -i);
		transferFunc[i].x = 1.0 * ( ((1.0 - 1.0) / (tf_end-tf_middle2)) * (tf_end -i) + 1.0);
		transferFunc[i].y = 0.3 * ( ((1.0 - 0.3) / (tf_end-tf_middle2)) * (tf_end -i) + 0.3);
		transferFunc[i].z = 0.3 * ( ((1.0 - 0.3) / (tf_end-tf_middle2)) * (tf_end -i) + 0.3);
	}
	for(int i=tf_end+1; i<256; i++){
	     transferFunc[i].w = 0.0f;
		 transferFunc[i].x = 1.0f;
		 transferFunc[i].y = 0.3f;
		 transferFunc[i].z = 0.3f;
	}
	//-------------------------------------------------------------------
	// create transfer function texture
  //  float4 transferFunc[] =
  //  {
  //     /* {  0.0, 0.0, 0.0, 0.0, },
  //      {  1.0, 0.0, 0.0, 1.0, },
  //      {  1.0, 0.5, 0.0, 1.0, },
  //      {  1.0, 1.0, 0.0, 1.0, },
  //      {  0.0, 1.0, 0.0, 1.0, },
  //      {  0.0, 1.0, 1.0, 1.0, },
  //      {  0.0, 0.0, 1.0, 1.0, },
  //      {  1.0, 0.0, 1.0, 1.0, },
  //      {  0.0, 0.0, 0.0, 0.0, },*/

		//{  0.0, 0.0, 0.0, 0.0, },
  //      {  0.0, 0.0, 0.0, 1.0, },
  //      {  0.0, 0.0, 0.1, 0.2, },
  //      {  0.3, 0.4, 0.5, 0.6, },
  //      {  0.7, 0.8, 0.9, 1.0, },
  //      {  1.0, 1.0, 1.0, 1.0, },
  //      {  1.0, 1.0, 1.0, 1.0, },
  //      {  1.0, 1.0, 1.0, 1.0, },
  //      {  1.0, 1.0, 1.0, 0.0, },
  //  };

    cudaChannelFormatDesc channelDesc2 = cudaCreateChannelDesc<float4>();
    cudaArray *d_transferFuncArray;
    checkCudaErrors(cudaMallocArray(&d_transferFuncArray, &channelDesc2, sizeof(transferFunc)/sizeof(float4), 1));
    checkCudaErrors(cudaMemcpyToArray(d_transferFuncArray, 0, 0, transferFunc, sizeof(transferFunc), cudaMemcpyHostToDevice));

    transferTex.filterMode = cudaFilterModePoint;
    transferTex.normalized = false;    // access with normalized texture coordinates
    transferTex.addressMode[0] = cudaAddressModeClamp;   // wrap texture coordinates

    // Bind the array to the texture
    checkCudaErrors(cudaBindTextureToArray(transferTex, d_transferFuncArray, channelDesc2));


	int size = 256*256;
	float4* TF2d_k;
	cudaMalloc((void**)&TF2d_k, size*sizeof(float4));
	cudaMemset(TF2d_k, 0, size*sizeof(float4));

	dim3 Db = dim3( 16, 16 ); 
    dim3 Dg = dim3( 16, 16 );
	
	TF2d_kernel<<<Dg, Db>>>(TF2d_k, 256); //pre-integral OTF init kernel - threads 4096*4096

	float4* TF2d;
	TF2d = new float4[size];
	memset(TF2d, 0, size*sizeof(float4));

	cudaMemcpy(TF2d, TF2d_k, size*sizeof(float4), cudaMemcpyDeviceToHost);
	
	cudaExtent Size = make_cudaExtent(256, 256, 1);
	cudaChannelFormatDesc channelDesc3 = cudaCreateChannelDesc<float4>();
    checkCudaErrors(cudaMalloc3DArray(&d_TF2dArray, &channelDesc3, Size));

    // copy data to 3D array
    cudaMemcpy3DParms copyParams2 = {0};
    copyParams2.srcPtr   = make_cudaPitchedPtr(TF2d, 256*sizeof(float4), 256, 256);
    copyParams2.dstArray = d_TF2dArray;
    copyParams2.extent   = Size;
    copyParams2.kind     = cudaMemcpyHostToDevice;
    checkCudaErrors(cudaMemcpy3D(&copyParams2));

    // set texture parameters
    tex_TF2d.normalized = true;                      // access with normalized texture coordinates
    tex_TF2d.filterMode = cudaFilterModeLinear;      // linear interpolation
    tex_TF2d.addressMode[0] = cudaAddressModeBorder;  // clamp texture coordinates
    tex_TF2d.addressMode[1] = cudaAddressModeBorder;
    tex_TF2d.addressMode[2] = cudaAddressModeBorder;
    // bind array to 3D texture
    checkCudaErrors(cudaBindTextureToArray(tex_TF2d, d_TF2dArray, channelDesc3));
	delete[] TF2d;
}

extern "C"
void freeCudaBuffers()
{
    checkCudaErrors(cudaFreeArray(d_volumeArray));
    checkCudaErrors(cudaFreeArray(d_transferFuncArray));
}


extern "C"
void render_kernel(dim3 gridSize, dim3 blockSize, uint *d_output, uint imageW, uint imageH,
                   float density, float brightness, float transferOffset, float transferScale)
{
    d_render<<<gridSize, blockSize>>>(d_output, imageW, imageH, density,
                                      brightness, transferOffset, transferScale);
}

extern "C"
void copyInvViewMatrix(float *invViewMatrix, size_t sizeofMatrix)
{
    checkCudaErrors(cudaMemcpyToSymbol(c_invViewMatrix, invViewMatrix, sizeofMatrix));
}


#endif // #ifndef _VOLUMERENDER_KERNEL_CU_
