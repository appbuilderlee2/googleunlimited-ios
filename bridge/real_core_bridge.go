// GoMobile bridge compiling the *real* upstream gotohp core package.
// No Google credentials, networking, or uploads are triggered by this method.
package bridge

import (
    "fmt"
    "app/core"
)

func Version() string { return "gotohp-core-bridge-0.1" }
func Healthcheck() string {
    o := core.UploadOptions{Threads: 2, Recursive: false, DeleteFromHost: false}
    return fmt.Sprintf("gotohp core linked; threads=%d; delete-originals=%t", o.Threads, o.DeleteFromHost)
}
