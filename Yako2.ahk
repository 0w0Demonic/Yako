#Requires AutoHotkey >=v2.1-alpha.9
/**
 * ```
 *  ,-.     ,_~*, /
 *     \  ,´_, ´ /        _,
 *      l´ (_|, /__   .*´  l\  _@&^""-._o
 *   <_´      `/\  (o)      `*$m^
 * ```
 * https://www.github.com/0w0Demonic/Yako
 * 
 * Yako is an AutoHotkey library that uses DLL injection to intercept window
 * messages in external applications, allowing you to modify and reprogram
 * their behavior.
 */
class Yako {
    Messages {
        get {
            static MapObj := Yako.MessageHandler()
            return MapObj
        }
    }

    static __New() {
        if (this == Yako) {
            return
        }
        Messages := this.Prototype.Messages.Subclass()
        BaseObj := ObjGetBase(this)
        for PropertyName in this.Prototype.OwnProps() {
            
        }
    }

    /**
     * A special map structure supporting inheritance from other maps
     * similar to a linked list.
     */
    class MessageHandler extends Map {
        /**
         * Returns a new MessageHandler map with the given base map to
         * inherit from.
         */
        __New(Next := Map()) {
            this.Default := false

            if (!(Next is Map)) {
                throw TypeError("Expected a Map",, Type(Next))
            }

            this.DefineProp("Next", {
                Get: (Instance) => Next
            })
        }

        /**
         * Returns an enumerator that iterates all properties in the current
         * mpa and down its entire base chain.
         */
        __Enum(ArgSize) {
            Methods := Map()
            MapObj := this

            Loop {
                for Name, Callback in (Map.Prototype.__Enum)(MapObj) {
                    if (!Methods.Has(Name)) {
                        Methods[Name] := Callback
                    }
                }
                if (!ObjHasOwnProp(MapObj, "Next")) {
                    break
                }
                MapObj := MapObj.Next
            }
            return Methods.__Enum(ArgSize)
        }

        /**
         * Returns a value from the MessageHandler map.
         */
        Get(Key, Default?) {
            return super.Get(Key, Default?) || this.Next.Get(Key, Default?)
        }

        /**
         * Getter that supports inheritance.
         */
        __Item[Key] {
            get {
                return super[Key] || this.Next[Key]
            }
        }

        /**
         * Returns a new MessageHandler with `this` as its base.
         */
        Subclass() {
            return Yako.MessageHandler(this)
        }
    }

    class Gui extends Yako {
        Move(Callback) {
            GetMethod(Callback)
            this.OnMessage(WM_MOVE := 0x0003, (GuiObj, wParam, lParam) {
                x := lParam & 0xFFFF
                y := (lParam >>> 16) & 0xFFFF
                return Callback(GuiObj, x, y)
            })
            return this
        }
    }
}




