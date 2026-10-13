//
//  ProjectFileTests+Goldens.swift
//  SwipesetTests
//

@testable import Swipeset

/// Projects as each format version saves them.
extension ProjectFileTests {
    /// A project as version 1 saves it. Every build must keep reading it.
    static let version1 = """
        {
          "formatVersion" : 1,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "cells" : [
                  {
                    "image" : {
                      "assetIdentifier" : "ABC123/L0/001",
                      "crop" : {
                        "centerX" : 0.25,
                        "centerY" : 0.5,
                        "scale" : 1.5
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                      "pixelHeight" : 3072,
                      "pixelWidth" : 2304
                    }
                  },
                  {

                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layout" : "twoColumns"
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    /// A project as version 2 saves it, with a slide and a panorama. Every build must keep reading it.
    static let version2 = """
        {
          "formatVersion" : 2,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "cells" : [
                  {

                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layout" : "single",
                "span" : 1
              },
              {
                "cells" : [
                  {
                    "image" : {
                      "assetIdentifier" : "ABC123/L0/001",
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 1
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000004",
                      "pixelHeight" : 1000,
                      "pixelWidth" : 4000
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                "layout" : "panorama",
                "span" : 4
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    /// A project as version 3 saves it, with a blurred slide under a text layer and a PNG
    /// picture layer. Every build must keep reading it.
    static let version3 = """
        {
          "formatVersion" : 3,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "blur" : 0.02,
                "cells" : [
                  {
                    "image" : {
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 2
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                      "pixelHeight" : 3072,
                      "pixelWidth" : 2304
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layers" : [
                  {
                    "content" : {
                      "text" : {
                        "alignment" : "leading",
                        "color" : {
                          "blue" : 1,
                          "green" : 1,
                          "red" : 1
                        },
                        "font" : "serif",
                        "hasShadow" : true,
                        "isHighlighted" : false,
                        "text" : "Lisbon"
                      }
                    },
                    "id" : "6A1F2B3C-0000-4000-8000-000000000004",
                    "placement" : {
                      "centerX" : 0.25,
                      "centerY" : 0.2,
                      "rotation" : -0.1,
                      "scale" : 1.5
                    }
                  },
                  {
                    "content" : {
                      "image" : {
                        "blur" : 0,
                        "borderColor" : {
                          "blue" : 1,
                          "green" : 1,
                          "red" : 1
                        },
                        "borderWidth" : 0.05,
                        "image" : {
                          "crop" : {
                            "centerX" : 0.5,
                            "centerY" : 0.5,
                            "scale" : 1
                          },
                          "fileFormat" : "png",
                          "id" : "6A1F2B3C-0000-4000-8000-000000000006",
                          "pixelHeight" : 600,
                          "pixelWidth" : 800
                        }
                      }
                    },
                    "id" : "6A1F2B3C-0000-4000-8000-000000000005",
                    "placement" : {
                      "centerX" : 0.7,
                      "centerY" : 0.75,
                      "rotation" : 0,
                      "scale" : 0.75
                    }
                  }
                ],
                "layout" : "single",
                "span" : 1
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    /// A project as version 4 saves it, with a slide in the standard style and a blurred one on
    /// black. Every build must keep reading it, and writes it back the same.
    static let version4 = """
        {
          "formatVersion" : 4,
          "project" : {
            "aspectRatio" : "1:1",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "cells" : [
                  {
                    "image" : {
                      "assetIdentifier" : "ABC123/L0/001",
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 1
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                      "pixelHeight" : 3072,
                      "pixelWidth" : 2304
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layout" : "single",
                "span" : 1,
                "style" : {
                  "background" : {
                    "blue" : 1,
                    "green" : 1,
                    "red" : 1
                  },
                  "border" : 0,
                  "spacing" : 0.01
                }
              },
              {
                "blur" : 0.02,
                "cells" : [
                  {
                    "image" : {
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 2
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000005",
                      "pixelHeight" : 2048,
                      "pixelWidth" : 2048
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000004",
                "layout" : "single",
                "span" : 1,
                "style" : {
                  "background" : {
                    "blue" : 0,
                    "green" : 0,
                    "red" : 0
                  },
                  "border" : 0.03,
                  "spacing" : 0.02
                }
              }
            ]
          }
        }
        """
}
