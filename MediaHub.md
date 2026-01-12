MediaHub — One-Page Foundation

What is MediaHub

MediaHub is a macOS application designed to replace Photos.app and Image Capture for users who want a simple, reliable, and scalable way to import, organize, and manage large photo and video libraries.

It keeps the simplicity and familiarity of Photos.app, while removing its structural limitations:
embedded libraries, fragile backups, poor interoperability, and lack of control over long-term storage.

MediaHub focuses on clear pipelines, explicit structure, and full compatibility with external tools.

⸻

Who MediaHub is for

MediaHub is built for:
	•	macOS users already comfortable with Photos.app
	•	Users managing large or growing libraries
	•	People who care about backup, portability, and long-term access
	•	Users who want to use external tools (DigiKam, ON1, exiftool, Finder)

MediaHub is not aimed at:
	•	cloud-first or mobile-only workflows
	•	fully automatic “magic” organization
	•	opaque, embedded, or vendor-locked storage models

⸻

Core Problem It Solves

Photos.app works well for casual usage, but becomes limiting when:
	•	libraries grow large
	•	backups must be transparent and reliable
	•	multiple libraries are needed
	•	external editing tools must coexist
	•	files must remain usable outside a proprietary container

MediaHub solves this by treating media as normal files on disk, organized in a clear and predictable structure, while still providing a Photos-like import and browsing experience.

⸻

Core Idea

MediaHub is built around pipelines.

A pipeline defines:
	•	where media comes from (iPhone, camera, folder, Photos library, etc.)
	•	how new items are detected
	•	how files are copied or staged
	•	how they are organized on disk
	•	how consistency is maintained over time

The default goal is simple and familiar:

Import photos and videos, then store them by year and month (YYYY/MM) in a transparent folder structure.

How this is implemented (Photos.app as an intermediary or not) remains open to investigation during specification.

⸻

Design Principles (Non-Negotiable)
	•	Simple by default
The core experience must feel no more complex than Photos.app.
	•	Transparent storage
Files live in normal folders, usable without MediaHub.
	•	Safe operations
No destructive actions without explicit confirmation.
	•	Deterministic behavior
Same inputs produce the same results. Re-running pipelines is safe.
	•	Interoperability first
External tools must not “break” MediaHub.
	•	Scalable by design
Multiple libraries, large volumes, long-term usage are first-class concerns.

⸻

Reference & Inspiration

MediaHub draws inspiration from:
	•	Photos.app → user familiarity and ease of use
	•	Image Capture → explicit import control
	•	iMazing → device-centric pipelines, transparency, reliability

It deliberately avoids the “all-in-one embedded library” model.

⸻

Definition of Success

MediaHub is successful if:
	•	A non-technical user can replace Photos.app without fear
	•	Large libraries remain fast, understandable, and backup-friendly
	•	Users can freely edit files with external tools without breaking the system
	•	Pipelines can evolve without invalidating existing libraries
	•	Users feel more in control, not more burdened

⸻

What This One-Page Is (and Is Not)

This document:
	•	defines intent and direction
	•	aligns future specifications
	•	constrains design decisions

It does not:
	•	define technical architecture
	•	lock implementation choices
	•	enumerate features or UI details

Those belong to the /specify phase.