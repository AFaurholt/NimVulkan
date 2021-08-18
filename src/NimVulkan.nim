import std/[strutils, bitops, rdstdin, strutils]
import nimgl/[vulkan, glfw]

proc init(): GLFWWindow =
  echo "Init glfw"
  assert glfwinit()
  echo "Init vk"
  assert vkInit()
  glfwWindowHint(glfw.GLFWClientApi, glfw.GLFWNoApi)
  echo "Create window"
  result = glfwCreateWindow(800, 600, "Learning Vulkan", nil, nil)

proc createInstance(): VkInstance =
  var appInfo: VkApplicationInfo = VkApplicationInfo(
    sType: VK_STRUCTURE_TYPE_APPLICATION_INFO,
    pApplicationName: "Nim Vulkan",
    applicationVersion: vkMakeVersion(1, 0, 0),
    pEngineName: "No engine",
    engineVersion: vkMakeVersion(1, 0, 0),
    apiVersion: vkApiVersion1_0
  )

  var createInfo: VkInstanceCreateInfo = VkInstanceCreateInfo(
    sType: VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    pApplicationInfo: addr appInfo
  )

  var glfwExtCount: uint32 = 0
  var glfwExt: cstringArray
  glfwExt = glfwGetRequiredInstanceExtensions(addr glfwExtCount)

  createInfo.enabledExtensionCount = glfwExtCount
  createInfo.ppEnabledExtensionNames = glfwExt
  createInfo.enabledLayerCount = 0

  if vkCreateInstance(addr createInfo, nil, addr result) != VK_SUCCESS:
    echo "Panic!"

proc getPhysicalDevices(instance: VkInstance): seq[VkPhysicalDevice] =
  var count: uint32
  doAssert vkEnumeratePhysicalDevices(instance, addr count, nil) == VK_SUCCESS
  result.newSeq(int count)
  doAssert vkEnumeratePhysicalDevices(instance, addr count, addr result[0]) == VK_SUCCESS

proc main() =
  let window = init()
  let instance = createInstance()

  echo "Enumerate props"
  var extCount: uint32 = 0
  discard vkEnumerateInstanceExtensionProperties(nil, addr extCount, nil)
  echo "Extension count: ", extCount

  var apiVer: uint32 = 0
  discard vkEnumerateInstanceVersion(addr apiVer)
  echo "API Version: ", apiVer

  echo vkVersionMajor(apiVer),".", vkVersionMinor(apiVer),".", vkVersionPatch(apiVer)

  echo "Enumerating physical devices"
  let physicalDevices = getPhysicalDevices(instance)
  for index, device in physicalDevices:
    var deviceProps: VkPhysicalDeviceProperties
    vkGetPhysicalDeviceProperties(device, addr deviceProps)
    echo index, ": ", deviceProps.deviceName.join
    echo deviceProps.deviceType
    var deviceFeat: VkPhysicalDeviceFeatures
    vkGetPhysicalDeviceFeatures(device, addr deviceFeat)
    echo "alphaToOne: ", bool deviceFeat.alphaToOne
    echo "depthBiasClamp: ", bool deviceFeat.depthBiasClamp
    echo "depthBounds: ", bool deviceFeat.depthBounds
    echo "depthClamp: ", bool deviceFeat.depthClamp
    echo "drawIndirectFirstInstance: ", bool deviceFeat.drawIndirectFirstInstance
    echo "dualSrcBlend: ", bool deviceFeat.dualSrcBlend
    echo "fillModeNonSolid: ", bool deviceFeat.fillModeNonSolid
    echo "fragmentStoresAndAtomics: ", bool deviceFeat.fragmentStoresAndAtomics
    echo "fullDrawIndexUint32: ", bool deviceFeat.fullDrawIndexUint32
    echo "geometryShader: ", bool deviceFeat.geometryShader
    echo "imageCubeArray: ", bool deviceFeat.imageCubeArray
    var deviceMem: VkPhysicalDeviceMemoryProperties
    vkGetPhysicalDeviceMemoryProperties(device, addr deviceMem)
    echo "Memory:\t| LOCAL_BIT\t| HOST_CACHED\t| COHERENT\t| HEAP INDEX"
    for i in 0..(deviceMem.memoryTypeCount-1):
      echo i, "\t| ", bool uint(deviceMem.memoryTypes[i].propertyFlags).masked(uint VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT), "\t\t| ",
        bool uint(deviceMem.memoryTypes[i].propertyFlags).masked(uint VK_MEMORY_PROPERTY_HOST_CACHED_BIT), "\t\t| ",
        bool uint(deviceMem.memoryTypes[i].propertyFlags).masked(uint VK_MEMORY_PROPERTY_HOST_COHERENT_BIT), "\t\t| ",
        deviceMem.memoryTypes[i].heapIndex
    echo "Heap size:"
    const giBit = 1024 * 1024 * 1024
    for i in 0..(deviceMem.memoryHeapCount-1):
      echo i, ": ", (float(deviceMem.memoryHeaps[i].size) / giBit), " Gbit"
    echo "Queues:\t| COUNT\t| GRAPHICS\t| COMPUTE\t| TRANSFER\t| SPARSE"
    var queueCount: uint32
    vkGetPhysicalDeviceQueueFamilyProperties(device, addr queueCount, nil)
    var queueSeq = newSeq[VkQueueFamilyProperties](queueCount)
    vkGetPhysicalDeviceQueueFamilyProperties(device, addr queueCount, addr queueSeq[0])
    for index, queueProp in queueSeq:
      echo index, "\t| "
      , queueProp.queueCount, "\t| "
      , bool uint(queueProp.queueFlags).masked(uint VK_QUEUE_GRAPHICS_BIT), "\t\t| "
      , bool uint(queueProp.queueFlags).masked(uint VK_QUEUE_COMPUTE_BIT),  "\t\t| "
      , bool uint(queueProp.queueFlags).masked(uint VK_QUEUE_TRANSFER_BIT), "\t\t| "
      , bool uint(queueProp.queueFlags).masked(uint VK_QUEUE_SPARSE_BINDING_BIT)

  var 
    deviceResponse: string
  discard readLineFromStdin("Pick device:", deviceResponse)

  var deviceQueueCreateInfo: VkDeviceQueueCreateInfo = VkDeviceQueueCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    , pNext: nil
    , flags: VkDeviceQueueCreateFlags 0
    , queueFamilyIndex: 0
    , queueCount: 1
    , pQueuePriorities: nil)

  var requiedFeatures: VkPhysicalDeviceFeatures = VkPhysicalDeviceFeatures(
    multiDrawIndirect: VkBool32 true
    , tessellationShader: VkBool32 true
    , geometryShader: VkBool32 true
  )
  var deviceCreateInfo: VkDeviceCreateInfo = VkDeviceCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
    , pNext: nil
    , flags: VkDeviceCreateFlags 0
    , pQueueCreateInfos: addr deviceQueueCreateInfo
    , queueCreateInfoCount: 1
    , enabledLayerCount: 0
    , ppEnabledLayerNames: nil
    , enabledExtensionCount: 0
    , ppEnabledExtensionNames: nil
    , pEnabledFeatures: addr requiedFeatures
  )
  
  var logicalDevice: VkDevice
  doAssert vkCreateDevice(
    physicalDevices[deviceResponse.parseUInt]
    , addr deviceCreateInfo
    , nil
    , addr logicalDevice) == VK_SUCCESS

  # var seqDeviceQueueCreateInfo: seq[VkDeviceQueueCreateInfo] = @[deviceQueueCreateInfo]
  # var deviceCreateInfo: VkDeviceCreateInfo =
  #   newVkDeviceCreateInfo(
  #     VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
  #     , nil
  #     , 0
  #     , 1
  #     , addr seqDeviceQueueCreateInfo[0]
  #   )

  while not windowShouldClose(window):
    glfwPollEvents()

  vkDestroyInstance(instance, nil)
  window.destroyWindow
  glfwTerminate()

main()