.PHONY: build app run dev test sprites banner clean

build:
	swift build

app:
	./scripts/build-app.sh

run: app
	-pkill -x Catification
	open build/Catification.app

dev: build
	-pkill -x Catification
	.build/debug/Catification

test:
	swift test

banner: build
	.build/debug/Catification --render-banner docs/media/banner.gif

sprites: build
	mkdir -p .preview
	.build/debug/Catification --dump-sprites .preview/sprites.png
	open .preview/sprites.png

clean:
	rm -rf .build build .preview
