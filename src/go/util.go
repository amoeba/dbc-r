package main

/*
#include <stdlib.h>
*/
import "C"
import "unsafe"

// nilCString returns a NULL *C.char, used to signal success to R callers.
func nilCString() *C.char {
	return (*C.char)(unsafe.Pointer(nil))
}
