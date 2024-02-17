package main

import (
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
	gpiosim "github.com/warthog618/go-gpiosim"
)

const (
	ENOLINE = -1
)

func retrieveLineOffset(g *gpiosim.Simpleton, spec string) (int, error) {
	offset, err := strconv.Atoi(spec)
	if err != nil {
		return ENOLINE, err
	}

	if offset < 0 || offset >= g.Config().NumLines {
		return ENOLINE, fmt.Errorf("offset must be an integer between 0 and %d; got %d", g.Config().NumLines-1, offset)
	}

	return offset, nil
}

func handleLineOffset(c *gin.Context, g *gpiosim.Simpleton, spec string) (int, error) {
	offset, err := retrieveLineOffset(g, spec)
	if err != nil {
		respondNotFound(c, err, gin.H{
			"offset": offset,
		})
	}

	return offset, err
}

func handleLevel(c *gin.Context, g *gpiosim.Simpleton, offset int) {
	level, err := g.Level(offset)
	if err != nil {
		respondInternalServerError(c, err, gin.H{"offset": offset, "level": level})
	} else {
		respondOk(c, gin.H{"offset": offset, "level": level})
	}
}

func handlePull(c *gin.Context, g *gpiosim.Simpleton, offset int) {
	pull, err := g.Pull(offset)
	if err != nil {
		respondInternalServerError(c, err, gin.H{"offset": offset, "pull": pull})
	} else {
		respondOk(c, gin.H{"offset": offset, "pull": pull})
	}
}

func respond(c *gin.Context, st int, err error, data gin.H) {
	c.JSON(st, gin.H{"error": err, "data": data})
}

func respondOk(c *gin.Context, data gin.H) {
	respond(c, http.StatusOK, nil, data)
}

func respondBadRequest(c *gin.Context, err error, data gin.H) {
	respond(c, http.StatusBadRequest, err, data)
}

func respondNotFound(c *gin.Context, err error, data gin.H) {
	respond(c, http.StatusNotFound, err, data)
}

func respondInternalServerError(c *gin.Context, err error, data gin.H) {
	respond(c, http.StatusInternalServerError, err, data)
}

func main() {
	lines, ok := os.LookupEnv("LINES")
	var linei int
	if ok {
		linec, err := strconv.Atoi(lines)
		if err != nil {
			fmt.Printf("error parsing LINES specification %v: %v\n", lines, err)
			os.Exit(1)
		} else {
			linei = linec
		}
	} else {
		linei = 9
	}

	g, err := gpiosim.NewSimpleton(linei)
	if err != nil {
		fmt.Printf("error creating simulated GPIO: %v\n", err)
		os.Exit(1)
	}

	defer g.Close()

	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		respondOk(c, gin.H{
			"chipname": g.ChipName(),
			"config":   g.Config(),
			"devpath":  g.DevPath(),
		})
	})

	r.GET("/chipname", func(c *gin.Context) {
		respondOk(c, gin.H{"chipname": g.ChipName()})
	})

	r.GET("/config", func(c *gin.Context) {
		respondOk(c, gin.H{"config": g.Config()})
	})

	r.GET("/devpath", func(c *gin.Context) {
		respondOk(c, gin.H{"devpath": g.DevPath()})
	})

	r.GET("/line/:offset/level", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		handleLevel(c, g, offset)
	})

	r.GET("/line/:offset/pull", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		handlePull(c, g, offset)
	})

	r.PUT("/line/:offset/pull/down", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		if err := g.Pulldown(offset); err != nil {
			respondInternalServerError(c, err, gin.H{"offset": offset})
		} else {
			handlePull(c, g, offset)
		}
	})

	r.PUT("/line/:offset/pull/up", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		if err := g.Pullup(offset); err != nil {
			respondInternalServerError(c, err, gin.H{"offset": offset})
		} else {
			handlePull(c, g, offset)
		}
	})

	r.PUT("/line/:offset/pull/:bias", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		bias, err := strconv.Atoi(c.Param("bias"))
		if err != nil {
			respondBadRequest(c, err, gin.H{"offset": offset, "bias": bias})
			return
		}

		if err := g.SetPull(offset, bias); err != nil {
			respondInternalServerError(c, err, gin.H{"offset": offset, "bias": bias})
		} else {
			handlePull(c, g, offset)
		}
	})

	r.PUT("/line/:offset/pull/toggle", func(c *gin.Context) {
		offset, err := handleLineOffset(c, g, c.Param("offset"))
		if err != nil {
			return
		}

		if err := g.Toggle(offset); err != nil {
			respondInternalServerError(c, err, gin.H{"offset": offset})
		} else {
			handlePull(c, g, offset)
		}
	})

	r.Run()
}
