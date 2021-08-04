{. define(vulkan).}

import std/[strutils, bitops, rdstdin]
import nimgl/[vulkan, glfw]

proc init(): GLFWWindow =
  echo "Init glfw"
  assert glfwinit()
  echo "Init vk"
  echo "\t", "Core 1_0"
  vkLoad1_0()
  echo "\t", "Surface"
  loadVK_KHR_surface()
  echo "\t", "Swapchain"
  loadVK_KHR_swapchain()
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
  echo glfwExt.cstringArrayToSeq(glfwExtCount)
  createInfo.enabledExtensionCount = glfwExtCount
  createInfo.ppEnabledExtensionNames = glfwExt
  when true:
    var layerCount: uint32
    doAssert vkEnumerateInstanceLayerProperties(addr layerCount, nil) == VK_SUCCESS
    var layerProperties = newSeq[VkLayerProperties](layerCount)
    doAssert vkEnumerateInstanceLayerProperties(addr layerCount, addr layerProperties[0]) == VK_SUCCESS
    var layerNames = newSeq[string](layerCount)
    for index, layer in layerProperties:
      layerNames[index] = $ cstring (unsafeAddr layer.layerName)
      echo layerNames[index]
    layerNames = @["VK_LAYER_KHRONOS_validation"]
    createInfo.enabledLayerCount = 1
    createInfo.ppEnabledLayerNames = allocCStringArray(layerNames)
  else:
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
  var extensions = newSeq[VkExtensionProperties](extCount)
  discard vkEnumerateInstanceExtensionProperties(nil, addr extCount, addr extensions[0])
  for i, extension in extensions:
    echo "\t", extension.extensionName.unsafeAddr.cstring

  var apiVer: uint32 = 0
  #discard vkEnumerateInstanceVersion(addr apiVer)
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
    echo "API Version: ", deviceProps.apiVersion
    echo vkVersionMajor(deviceProps.apiVersion),".", vkVersionMinor(deviceProps.apiVersion),".", vkVersionPatch(deviceProps.apiVersion)
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
    queueFamResponse: string
    queueCountResponse: string
  discard readLineFromStdin("Pick device:", deviceResponse)
  discard readLineFromStdin("Pick queue family:", queueFamResponse)
  discard readLineFromStdin("Pick queue count:", queueCountResponse)

  var priorities: seq[float32] = newSeq[float32](queueCountResponse.parseUint)
  var deviceQueueCreateInfo: VkDeviceQueueCreateInfo = VkDeviceQueueCreateInfo(
    sType: VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO
    , pNext: nil
    , flags: VkDeviceQueueCreateFlags 0
    , queueFamilyIndex: uint32 queueFamResponse.parseUInt
    , queueCount: uint32 len priorities
    , pQueuePriorities: addr priorities[0])

  var deviceFeatures: VkPhysicalDeviceFeatures
  var deviceExtensions: seq[string] = @["VK_KHR_swapchain"]
  var deviceCreateInfo: VkDeviceCreateInfo
  deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
  deviceCreateInfo.pQueueCreateInfos = addr deviceQueueCreateInfo
  deviceCreateInfo.queueCreateInfoCount = 1
  deviceCreateInfo.enabledExtensionCount = uint32 len deviceExtensions
  deviceCreateInfo.ppEnabledExtensionNames = allocCStringArray(deviceExtensions)
  deviceCreateInfo.pEnabledFeatures = addr deviceFeatures

  var physicalDevice = physicalDevices[deviceResponse.parseUInt]
  var logicalDevice: VkDevice
  var queue: VkQueue

  doAssert vkCreateDevice(physicalDevice, addr deviceCreateInfo, nil, addr logicalDevice) == VK_SUCCESS
  vkGetDeviceQueue(logicalDevice, uint32 queueFamResponse.parseUInt, 0, addr queue)
  
  var surface: VkSurfaceKHR
  var surfaceCaps: VkSurfaceCapabilitiesKHR

  doAssert glfwCreateWindowSurface(instance, window, nil, addr surface) == VK_SUCCESS
  doAssert vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, addr surfaceCaps) == VK_SUCCESS

  var surfaceFormatsCount: uint32
  doAssert vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, addr surfaceFormatsCount, nil) == VK_SUCCESS
  var surfaceFormats = newSeq[VkSurfaceFormatKHR](surfaceFormatsCount)
  doAssert vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, addr surfaceFormatsCount, addr surfaceFormats[0]) == VK_SUCCESS

  var surfaceFormatindex = 0

  for index, surfaceFormat in surfaceFormats:
    echo "index: ", index
    echo "colorSpace: ", surfaceFormat.colorSpace
    echo "format: ", surfaceFormat.format
    if surfaceFormat.format == VK_FORMAT_B8G8R8A8_SRGB:
      surfaceFormatindex = index

  var surfaceFormat = surfaceFormats[surfaceFormatindex]
  
  var presentMode = VK_PRESENT_MODE_FIFO_KHR
  var extent: VkExtent2D
  extent = surfaceCaps.currentExtent
  echo "extent {", extent.width, ", ", extent.height, "}"

  var surfaceSupport: VkBool32
  doAssert vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, 0, surface, addr surfaceSupport) == VK_SUCCESS
  doAssert surfaceSupport.int == VK_TRUE

  var swapChainCreationInfo: VkSwapchainCreateInfoKHR
  swapChainCreationInfo.sType = cast[VkStructureType](1000001000)
  swapChainCreationInfo.surface = surface
  swapChainCreationInfo.minImageCount = surfaceCaps.minImageCount
  swapChainCreationInfo.imageFormat = surfaceFormat.format
  swapChainCreationInfo.imageColorSpace = surfaceFormat.colorSpace
  swapChainCreationInfo.imageExtent = extent
  swapChainCreationInfo.imageArrayLayers = 1
  swapChainCreationInfo.imageUsage = cast[VkImageUsageFlags](VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)
  swapChainCreationInfo.preTransform = surfaceCaps.currentTransform
  swapChainCreationInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR
  swapChainCreationInfo.presentMode = presentMode
  swapChainCreationInfo.clipped = VkBool32 1
  swapChainCreationInfo.oldSwapchain = VkSwapchainKHR 0

  var swapChain: VkSwapchainKHR

  doAssert vkCreateSwapchainKHR(logicalDevice, addr swapChainCreationInfo, nil, addr swapChain) == VK_SUCCESS

  var swapChainImageCount: uint32
  doAssert vkGetSwapchainImagesKHR(logicalDevice, swapChain, addr swapChainImageCount, nil) == VK_SUCCESS
  var swapChainImages = newSeq[VkImage](swapChainImageCount)
  doAssert vkGetSwapchainImagesKHR(logicalDevice, swapChain, addr swapChainImageCount, addr swapChainImages[0]) == VK_SUCCESS

  var swapChainImageViews = newSeq[VkImageView](swapChainImageCount)
  for index, image in swapChainImages:
    var imageViewCreateInfo: VkImageViewCreateInfo
    imageViewCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
    imageViewCreateInfo.image = image
    imageViewCreateInfo.format = surfaceFormat.format
    imageViewCreateInfo.viewType = VK_IMAGE_VIEW_TYPE_2D
    imageViewCreateInfo.components.a = VK_COMPONENT_SWIZZLE_IDENTITY
    imageViewCreateInfo.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
    imageViewCreateInfo.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
    imageViewCreateInfo.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
    imageViewCreateInfo.subresourceRange.aspectMask = cast[VkImageAspectFlags](VK_IMAGE_ASPECT_COLOR_BIT)
    imageViewCreateInfo.subresourceRange.baseArrayLayer = 0
    imageViewCreateInfo.subresourceRange.baseMipLevel = 0
    imageViewCreateInfo.subresourceRange.layerCount = 1
    imageViewCreateInfo.subresourceRange.levelCount = 1

    doAssert vkCreateImageView(logicalDevice, addr imageViewCreateinfo, nil, addr swapChainImageViews[index]) == VK_SUCCESS

  var vertexShaderCode = open("src/vertexShader.vert.spv", FileMode.fmRead)
  var fragmentShaderCode = open("src/fragmentShader.frag.spv", FileMode.fmRead)

  var buffer: seq[uint32]
  var size = vertexShaderCode.getFileSize
  buffer.setLen(size div sizeof(uint32))

  var lengthRead = vertexShaderCode.readBuffer(addr buffer[0], size)
  doAssert lengthRead == size

  var shaderCreateInfo: VkShaderModuleCreateInfo
  shaderCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO
  shaderCreateInfo.codeSize = uint size
  shaderCreateInfo.pCode = addr buffer[0]

  var vertexShaderModule: VkShaderModule
  var fragmentShaderModule: VkShaderModule

  doAssert vkCreateShaderModule(logicalDevice, addr shaderCreateInfo, nil, addr vertexShaderModule) == VK_SUCCESS

  size = fragmentShaderCode.getFileSize
  buffer.setLen(size div sizeof(uint32))

  lengthRead = fragmentShaderCode.readBuffer(addr buffer[0], size)
  doAssert lengthRead == size

  shaderCreateInfo.codeSize = uint size
  shaderCreateInfo.pCode = addr buffer[0]

  doAssert vkCreateShaderModule(logicalDevice, addr shaderCreateInfo, nil, addr fragmentShaderModule) == VK_SUCCESS

  var shaderStageCreateInfo: array[2, VkPipelineShaderStageCreateInfo]

  shaderStageCreateInfo[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  shaderStageCreateInfo[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
  shaderStageCreateInfo[0].stage = VK_SHADER_STAGE_VERTEX_BIT
  shaderStageCreateInfo[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT
  shaderStageCreateInfo[0].module = vertexShaderModule
  shaderStageCreateInfo[1].module = fragmentShaderModule
  shaderStageCreateInfo[0].pName = "main"
  shaderStageCreateInfo[1].pName = "main"

  var vertexInputCreateInfo: VkPipelineVertexInputStateCreateInfo
  vertexInputCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
  vertexInputCreateInfo.pVertexAttributeDescriptions = nil
  vertexInputCreateInfo.pVertexBindingDescriptions = nil
  vertexInputCreateInfo.vertexAttributeDescriptionCount = 0
  vertexInputCreateInfo.vertexBindingDescriptionCount = 0

  var inputAssemblyCreateInfo: VkPipelineInputAssemblyStateCreateInfo
  inputAssemblyCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
  inputAssemblyCreateInfo.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST

  var viewport: VkViewport
  viewport.x = 0.0
  viewport.y = 0.0
  viewport.width = float32 extent.width
  viewport.height = float32 extent.height
  viewport.minDepth = 0.0
  viewport.maxDepth = 0.0

  var scissor: VkRect2D
  scissor.offset = VkOffset2D(x: 0, y: 0)
  scissor.extent = extent

  var viewportCreateInfo: VkPipelineViewportStateCreateInfo
  viewportCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO
  viewportCreateInfo.viewportCount = 1
  viewportCreateInfo.pViewports = addr viewport
  viewportCreateInfo.scissorCount = 1
  viewportCreateInfo.pScissors = addr scissor

  var rasterizerCreateInfo: VkPipelineRasterizationStateCreateInfo
  rasterizerCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO
  rasterizerCreateInfo.depthClampEnable = Vkbool32 0
  rasterizerCreateInfo.rasterizerDiscardEnable = Vkbool32 0
  rasterizerCreateInfo.polygonMode = VK_POLYGON_MODE_FILL
  rasterizerCreateInfo.lineWidth = 1.0
  rasterizerCreateInfo.cullMode = cast[VkCullModeFlags](VK_CULL_MODE_BACK_BIT)
  rasterizerCreateInfo.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE
  rasterizerCreateInfo.depthBiasEnable = VkBool32 0
  rasterizerCreateInfo.depthBiasClamp = 0.0
  rasterizerCreateInfo.depthBiasConstantFactor = 0.0
  rasterizerCreateInfo.depthBiasSlopeFactor = 0.0

  var MSAACreateInfo: VkPipelineMultisampleStateCreateInfo
  MSAACreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
  MSAACreateInfo.alphaToCoverageEnable = VkBool32 0
  MSAACreateInfo.alphaToOneEnable = VkBool32 0
  MSAACreateInfo.minSampleShading = 1.0
  MSAACreateInfo.pSampleMask = nil
  MSAACreateInfo.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT
  MSAACreateInfo.sampleShadingEnable = VkBool32 0

  var blendAttachState: VkPipelineColorBlendAttachmentState
  blendAttachState.blendEnable = VkBool32 0

  var blendStateCreateInfo: VkPipelineColorBlendStateCreateInfo
  blendStateCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
  blendStateCreateInfo.attachmentCount = 1
  blendStateCreateInfo.pAttachments = addr blendAttachState
  blendStateCreateInfo.logicOpEnable = VkBool32 0

  var layoutCreateInfo: VkPipelineLayoutCreateInfo
  layoutCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
  layoutCreateInfo.setLayoutCount = 0
  layoutCreateInfo.pSetLayouts = nil
  layoutCreateInfo.pushConstantRangeCount = 0
  layoutCreateInfo.pPushConstantRanges = nil

  var pipelineLayout: VkPipelineLayout

  doAssert vkCreatePipelineLayout(logicalDevice, addr layoutCreateInfo, nil, addr pipelineLayout) == VK_SUCCESS

  var colorAttachementDescription: VkAttachmentDescription
  colorAttachementDescription.format = surfaceFormat.format
  colorAttachementDescription.samples = VK_SAMPLE_COUNT_1_BIT
  colorAttachementDescription.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR
  colorAttachementDescription.storeOp = VK_ATTACHMENT_STORE_OP_STORE
  colorAttachementDescription.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE
  colorAttachementDescription.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE
  colorAttachementDescription.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
  colorAttachementDescription.finalLayout = cast[VkImageLayout](1000001002)

  var colorAttachmentReference: VkAttachmentReference
  colorAttachmentReference.attachment = 0
  colorAttachmentReference.layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL

  var subpassDescription: VkSubpassDescription
  subpassDescription.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS
  subpassDescription.colorAttachmentCount = 1
  subpassDescription.pColorAttachments = addr colorAttachmentReference

  var renderPassCreateInfo: VkRenderPassCreateInfo
  renderPassCreateInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
  renderPassCreateInfo.attachmentCount = 1
  renderPassCreateInfo.pAttachments = addr colorAttachementDescription
  renderPassCreateInfo.subpassCount = 1
  renderPassCreateInfo.pSubpasses = addr subpassDescription

  var renderPass: VkRenderPass

  doAssert vkCreateRenderPass(logicalDevice, addr renderPassCreateInfo, nil, addr renderPass) == VK_SUCCESS

  var graphicsPipelineCreateInfo: VkGraphicsPipelineCreateInfo
  graphicsPipelineCreateInfo.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO
  graphicsPipelineCreateInfo.stageCount = 2
  graphicsPipelineCreateInfo.pStages = addr shaderStageCreateInfo[0]
  graphicsPipelineCreateInfo.pVertexInputState = addr vertexInputCreateInfo
  graphicsPipelineCreateInfo.pInputAssemblyState = addr inputAssemblyCreateInfo
  graphicsPipelineCreateInfo.pViewportState = addr viewportCreateInfo
  graphicsPipelineCreateInfo.pRasterizationState = addr rasterizerCreateInfo
  graphicsPipelineCreateInfo.pMultisampleState = addr MSAACreateInfo
  graphicsPipelineCreateInfo.pDepthStencilState = nil
  graphicsPipelineCreateInfo.pColorBlendState = addr blendStateCreateInfo
  graphicsPipelineCreateInfo.pDynamicState = nil
  graphicsPipelineCreateInfo.layout = pipelineLayout
  graphicsPipelineCreateInfo.renderPass = renderPass
  graphicsPipelineCreateInfo.subpass = 0

  var graphicsPipeline: VkPipeline

  doAssert vkCreateGraphicsPipelines(logicalDevice, VkPipelineCache 0, 1, addr graphicsPipelineCreateInfo, nil, addr graphicsPipeline) == VK_SUCCESS

  var frameBuffers = newSeq[VkFramebuffer](len swapChainImages)

  for index, imageView in swapChainImageViews:
    var imageViews: seq[VkImageView] = @[imageView]

    var frameBufferCreateInfo: VkFramebufferCreateInfo
    frameBufferCreateInfo.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO
    frameBufferCreateInfo.renderPass = renderPass
    frameBufferCreateInfo.attachmentCount = 1
    frameBufferCreateInfo.pAttachments = addr imageViews[0]
    frameBufferCreateInfo.width = extent.width
    frameBufferCreateInfo.height = extent.height
    frameBufferCreateInfo.layers = 1

    doAssert vkCreateFramebuffer(logicalDevice, addr frameBufferCreateinfo, nil, addr frameBuffers[index]) == VK_SUCCESS

  var commandPoolCreateInfo: VkCommandPoolCreateInfo
  commandPoolCreateInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO
  commandPoolCreateInfo.queueFamilyIndex = uint32 queueFamResponse.parseUInt

  var commandPool: VkCommandPool

  doAssert vkCreateCommandPool(logicalDevice, addr commandPoolCreateInfo, nil, addr commandPool) == VK_SUCCESS

  var commandBuffers = newSeq[VkCommandBuffer](len swapChainImages)

  var cmdBufferAlocInfo: VkCommandBufferAllocateInfo
  cmdBufferAlocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO
  cmdBufferAlocInfo.commandPool = commandPool
  cmdBufferAlocInfo.commandBufferCount = uint32 len commandBuffers
  cmdBufferAlocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY

  doAssert vkAllocateCommandBuffers(logicalDevice, addr cmdBufferAlocInfo, addr commandBuffers[0]) == VK_SUCCESS

  for index, commandBuffer in commandBuffers:
    var beginInfo: VkCommandBufferBeginInfo
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO

    doAssert vkBeginCommandBuffer(commandBuffer, addr beginInfo) == VK_SUCCESS

    var clearColor: VkClearValue
    clearColor.color.float32 = [0'f32, 0'f32, 0'f32, 1'f32]

    var renderPassBeginInfo: VkRenderPassBeginInfo
    renderPassBeginInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO
    renderPassBeginInfo.renderPass = renderPass
    renderPassBeginInfo.framebuffer = frameBuffers[index]
    renderPassBeginInfo.renderArea = scissor
    renderPassBeginInfo.clearValueCount = 1
    renderPassBeginInfo.pClearValues = addr clearColor

    vkCmdBeginRenderPass(commandBuffer, addr renderpassBeginInfo, VK_SUBPASS_CONTENTS_INLINE)

    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)

    vkCmdDraw(commandBuffer, 3, 1, 0, 0)

    vkCmdEndRenderPass(commandBuffer)

    doAssert vkEndCommandBuffer(commandBuffer) == VK_SUCCESS

  # var deviceCreateInfo: VkDeviceCreateInfo =
  

  # doAssert vkCreateDevice(
  #   physicalDevice: physicalDevices[deviceResponse.parseUInt]
  #   , pCreateInfo: )

  # var seqDeviceQueueCreateInfo: seq[VkDeviceQueueCreateInfo] = @[deviceQueueCreateInfo]
  # var deviceCreateInfo: VkDeviceCreateInfo =
  #   newVkDeviceCreateInfo(
  #     VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO
  #     , nil
  #     , 0
  #     , 1
  #     , addr seqDeviceQueueCreateInfo[0]
  #   )

  var renderReady, renderDone: VkSemaphore

  var semaphoreCreateInfo: VkSemaphoreCreateInfo
  semaphoreCreateInfo.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO

  doAssert vkCreateSemaphore(logicalDevice, addr semaphoreCreateInfo, nil, addr renderReady) == VK_SUCCESS and vkCreateSemaphore(logicalDevice, addr semaphoreCreateInfo, nil, addr renderDone) == VK_SUCCESS

  while not windowShouldClose(window):
    glfwPollEvents()
    var imageIndex: uint32
    doAssert vkAcquireNextImageKHR(logicalDevice, swapChain, 100_000_000, renderReady, VkFence 0, addr imageIndex) == VK_SUCCESS

    var waitSemaphores: seq[VkSemaphore] = @[renderReady]
    var signalSemaphores: seq[VkSemaphore] = @[renderDone]
    var waitMasks: seq[VkPipelineStageFlags] = @[cast[VkPipelineStageFlags](VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)]

    var submitInfo: VkSubmitInfo
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO
    submitInfo.waitSemaphoreCount = 1
    submitInfo.pWaitSemaphores = addr waitSemaphores[0]
    submitInfo.pWaitDstStageMask = addr waitMasks[0]
    submitInfo.commandBufferCount = 1
    submitInfo.pCommandBuffers = addr commandBuffers[imageIndex]
    submitInfo.signalSemaphoreCount = 1
    submitInfo.pSignalSemaphores = addr signalSemaphores[0]

    doAssert vkQueueSubmit(queue, 1, addr submitInfo, VkFence 0) == VK_SUCCESS

    var presentInfo: VkPresentInfoKHR
    presentInfo.sType = cast[VkStructureType](1000001001)
    presentInfo.waitSemaphoreCount = 1
    presentInfo.pWaitSemaphores = addr signalSemaphores[0]
    presentInfo.swapchainCount = 1
    presentInfo.pSwapchains = addr swapChain
    presentInfo.pImageIndices = addr imageIndex

    doAssert vkQueuePresentKHR(queue, addr presentInfo) == VK_SUCCESS

    doAssert vkQueueWaitIdle(queue) == VK_SUCCESS
    

  vkDestroyInstance(instance, nil)
  window.destroyWindow
  glfwTerminate()

main()