# FA 24 TEST CASES

## Coremark
* Industry standard benchmarking suite

## FFT
* Performs Fast Fourier Transform on multiple input signals
* Utilizes arithmetic units heavily
* Expresses good ILP

## Mergesort
* Performs merge sort on multiple input arrays
* Many data-dependent branches
* Many loads/stores
 
## AES-SHA
* Performs AES encryptions and SHA-256 hash on input stream
* Has data reuse
* Utilizes arithmetic units heavily
* Expresses good ILP
* Many loads/stores, with high memory-level parallelism
  
## Compression
* Perfroms Huffman Compression on a random string from Mary Shelley's Frankenstein
* Low data reuse
* Large loops with data-dependent accesses. 
* Link to full text of Frankenstein: https://www.gutenberg.org/ebooks/84
  
## RSA
* Performs [PKCS-compliant](https://en.wikipedia.org/wiki/PKCS_1)
  288-bit RSA key generation (using Miller-Rabin primality test),
  encryption, and decryption
* Also uses a bignum library to handle large integer computations
* Utilizes arithmetic units heavily
* Expresses good ILP

## Ray Tracing
* Performs ray tracing based render of a simple scene with no reflections
* Expresses good ILP
* Many loads/stores, with high memory-level parallelism
