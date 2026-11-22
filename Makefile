APP = Beam.app

.PHONY: install run test lint app clean

app:
	swift build -c release
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Beam $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign - $(APP)

install: app
	pkill -x Beam || true
	rm -rf /Applications/Beam.app && cp -R $(APP) /Applications/
	open /Applications/Beam.app

run: app
	open $(APP)

test:
	swift test

lint:
	swift build -Xswiftc -warnings-as-errors

clean:
	rm -rf .build $(APP)
