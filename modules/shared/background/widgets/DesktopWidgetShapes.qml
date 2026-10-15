pragma Singleton
pragma ComponentBehavior: Bound
import QtQml
import qs.services
import qs.modules.common.widgets

QtObject {
    readonly property var choices: [
        { value: "Circle", label: Translation.tr("Circle"), shape: MaterialShape.Shape.Circle },
        { value: "Square", label: Translation.tr("Square"), shape: MaterialShape.Shape.Square },
        { value: "Slanted", label: Translation.tr("Slanted"), shape: MaterialShape.Shape.Slanted },
        { value: "Arch", label: Translation.tr("Arch"), shape: MaterialShape.Shape.Arch },
        { value: "Fan", label: Translation.tr("Fan"), shape: MaterialShape.Shape.Fan },
        { value: "Arrow", label: Translation.tr("Arrow"), shape: MaterialShape.Shape.Arrow },
        { value: "SemiCircle", label: Translation.tr("Semi Circle"), shape: MaterialShape.Shape.SemiCircle },
        { value: "Oval", label: Translation.tr("Oval"), shape: MaterialShape.Shape.Oval },
        { value: "Pill", label: Translation.tr("Pill"), shape: MaterialShape.Shape.Pill },
        { value: "Triangle", label: Translation.tr("Triangle"), shape: MaterialShape.Shape.Triangle },
        { value: "Diamond", label: Translation.tr("Diamond"), shape: MaterialShape.Shape.Diamond },
        { value: "ClamShell", label: Translation.tr("Clam Shell"), shape: MaterialShape.Shape.ClamShell },
        { value: "Pentagon", label: Translation.tr("Pentagon"), shape: MaterialShape.Shape.Pentagon },
        { value: "Gem", label: Translation.tr("Gem"), shape: MaterialShape.Shape.Gem },
        { value: "Sunny", label: Translation.tr("Sunny"), shape: MaterialShape.Shape.Sunny },
        { value: "VerySunny", label: Translation.tr("Very Sunny"), shape: MaterialShape.Shape.VerySunny },
        { value: "Cookie4Sided", label: Translation.tr("Cookie4 Sided"), shape: MaterialShape.Shape.Cookie4Sided },
        { value: "Cookie6Sided", label: Translation.tr("Cookie6 Sided"), shape: MaterialShape.Shape.Cookie6Sided },
        { value: "Cookie7Sided", label: Translation.tr("Cookie7 Sided"), shape: MaterialShape.Shape.Cookie7Sided },
        { value: "Cookie9Sided", label: Translation.tr("Cookie9 Sided"), shape: MaterialShape.Shape.Cookie9Sided },
        { value: "Cookie12Sided", label: Translation.tr("Cookie12 Sided"), shape: MaterialShape.Shape.Cookie12Sided },
        { value: "Ghostish", label: Translation.tr("Ghostish"), shape: MaterialShape.Shape.Ghostish },
        { value: "Clover4Leaf", label: Translation.tr("Clover4 Leaf"), shape: MaterialShape.Shape.Clover4Leaf },
        { value: "Clover8Leaf", label: Translation.tr("Clover8 Leaf"), shape: MaterialShape.Shape.Clover8Leaf },
        { value: "Burst", label: Translation.tr("Burst"), shape: MaterialShape.Shape.Burst },
        { value: "SoftBurst", label: Translation.tr("Soft Burst"), shape: MaterialShape.Shape.SoftBurst },
        { value: "Boom", label: Translation.tr("Boom"), shape: MaterialShape.Shape.Boom },
        { value: "SoftBoom", label: Translation.tr("Soft Boom"), shape: MaterialShape.Shape.SoftBoom },
        { value: "Flower", label: Translation.tr("Flower"), shape: MaterialShape.Shape.Flower },
        { value: "Puffy", label: Translation.tr("Puffy"), shape: MaterialShape.Shape.Puffy },
        { value: "PuffyDiamond", label: Translation.tr("Puffy Diamond"), shape: MaterialShape.Shape.PuffyDiamond },
        { value: "PixelCircle", label: Translation.tr("Pixel Circle"), shape: MaterialShape.Shape.PixelCircle },
        { value: "PixelTriangle", label: Translation.tr("Pixel Triangle"), shape: MaterialShape.Shape.PixelTriangle },
        { value: "Bun", label: Translation.tr("Bun"), shape: MaterialShape.Shape.Bun },
        { value: "Heart", label: Translation.tr("Heart"), shape: MaterialShape.Shape.Heart },
    ]

    function shapeForName(name: string): int {
        return choices.find(choice => choice.value === name)?.shape ?? MaterialShape.Shape.Cookie4Sided;
    }
}
