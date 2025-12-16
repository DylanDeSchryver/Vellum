#!/usr/bin/env python3
"""
Vellum App Icon Generator
Generates a 1024x1024 app icon matching the splash screen design:
- Sepia gradient background
- White translucent rounded rectangle
- White closed book icon

Run: python3 generate_icon.py
Requires: pip3 install Pillow
"""

from PIL import Image, ImageDraw
import os

def create_app_icon(size=1024):
    # Create image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # iOS app icon corner radius (about 22% of size)
    corner_radius = int(size * 0.22)
    
    # Background gradient colors from ThemeManager sepia theme
    # gradientColors: [Color(red: 0.60, green: 0.45, blue: 0.35), Color(red: 0.45, green: 0.30, blue: 0.20)]
    top_color = (153, 115, 89)     # RGB for (0.60, 0.45, 0.35)
    bottom_color = (115, 77, 51)   # RGB for (0.45, 0.30, 0.20)
    
    # Draw gradient background
    for y in range(size):
        ratio = y / size
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    
    # Apply rounded corner mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size, size)], radius=corner_radius, fill=255)
    img.putalpha(mask)
    
    # White translucent rounded rectangle (like the SwiftUI ZStack)
    # .fill(.white.opacity(0.2)) - frame 100x100 scaled to icon
    rect_size = int(size * 0.55)  # Proportional to the 100x100 in a ~180pt icon area
    rect_x = (size - rect_size) // 2
    rect_y = (size - rect_size) // 2
    rect_radius = int(size * 0.095)  # cornerRadius: 24 proportionally
    
    # Create translucent overlay
    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    overlay_draw.rounded_rectangle(
        [(rect_x, rect_y), (rect_x + rect_size, rect_y + rect_size)],
        radius=rect_radius,
        fill=(255, 255, 255, 51)  # white at 20% opacity (0.2 * 255 = 51)
    )
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)
    
    # Draw closed book icon (SF Symbol "book.closed.fill" style)
    # White color
    book_color = (255, 255, 255, 255)
    
    # Book dimensions - roughly 50% of the icon centered
    book_width = int(size * 0.32)
    book_height = int(size * 0.40)
    book_x = (size - book_width) // 2
    book_y = (size - book_height) // 2
    
    # Create book overlay for proper alpha
    book_overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    book_draw = ImageDraw.Draw(book_overlay)
    
    # Spine width
    spine_w = int(book_width * 0.18)
    
    # Draw the book cover (main rectangle with rounded corners)
    book_radius = int(size * 0.02)
    book_draw.rounded_rectangle(
        [(book_x, book_y), (book_x + book_width, book_y + book_height)],
        radius=book_radius,
        fill=book_color
    )
    
    # Draw spine curve on left side (darker indent to show spine)
    # Create a subtle spine effect by drawing a slightly darker/indented area
    spine_indent = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    spine_draw = ImageDraw.Draw(spine_indent)
    
    # Spine shadow/indent line
    spine_x = book_x + spine_w
    spine_draw.line(
        [(spine_x, book_y + int(size * 0.015)), (spine_x, book_y + book_height - int(size * 0.015))],
        fill=(200, 150, 100, 80),
        width=int(size * 0.008)
    )
    
    # Draw pages on right edge (the classic book.closed look)
    pages_width = int(size * 0.025)
    pages_x = book_x + book_width - pages_width
    
    # Pages are shown as lines on the right edge
    for i in range(4):
        line_x = pages_x + int(i * size * 0.005)
        book_draw.line(
            [(line_x, book_y + int(size * 0.025)), (line_x, book_y + book_height - int(size * 0.025))],
            fill=(220, 180, 140, 120),
            width=int(size * 0.003)
        )
    
    # Composite book onto main image
    img = Image.alpha_composite(img, book_overlay)
    img = Image.alpha_composite(img, spine_indent)
    
    return img

def main():
    print("Generating Vellum app icon...")
    
    # Generate 1024x1024 icon
    icon = create_app_icon(1024)
    
    # Save to Assets folder
    output_dir = "Vellum/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, "AppIcon.png")
    icon.save(output_path, "PNG")
    print(f"✓ Saved: {output_path}")
    
    # Update Contents.json to reference the icon
    contents_json = '''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''
    
    contents_path = os.path.join(output_dir, "Contents.json")
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"✓ Updated: {contents_path}")
    
    print("\n✅ App icon generated successfully!")
    print("Open Xcode and the icon should appear in Assets.xcassets")

if __name__ == "__main__":
    main()
